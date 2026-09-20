#!/usr/bin/env bash
set -euo pipefail

readonly GIF_FPS=15
readonly GIF_WIDTH=480
readonly JPEG_QUALITY=95

usage() {
  cat <<'USAGE'
Usage: convert-to <mp3|mp4|gif|jpg|png> [-R] [--cover PICTURE] [options] FILE...

Convert files that are already on disk. To fetch something, use download,
which lets the downloader do its own conversion while it still holds the
source streams and metadata.

  convert-to mp3 *.m4a          encode the audio to mp3
  convert-to mp4 clip.mkv       remux when the codecs already fit, else transcode
  convert-to mp4 song.mp3       cover art plus audio, as a still video
  convert-to mp3 *.flac --cover folder.jpg
                                embed that picture as every file's cover art
  convert-to mp4 song.mp3 --cover art.jpg
                                a still video of that picture, which is also
                                embedded as the mp4's cover for thumbnails
  convert-to mp3 -R song.mp3 --cover art.jpg
                                change the cover of song.mp3 itself
  convert-to gif clip.mp4       two-pass palette, 15 fps, 480px wide
  convert-to jpg *.png *.webp   still images through ImageMagick
  convert-to png photo.webp

Options go to ffmpeg, or to ImageMagick for jpg and png. An animated or
multi-page image is refused rather than split into one file per frame.

mp3 keeps the source's cover art. --cover replaces it, and when the input is
already an mp3 the audio is copied rather than re-encoded, so adding a picture
costs no quality. JPEG and PNG pictures are embedded as they are; anything else
becomes a JPEG, since those are the two formats players read.

The output sits beside the input under the same name. Converting a file into
its own name writes NAME.converted.EXT instead.

-R, --replace   the output takes the input's place: song.mp3 is rewritten in
                place, and song.flac is deleted once song.mp3 exists. The
                original goes only after its replacement is fully written and
                not empty; a failure leaves it as it was.

Without -R nothing you already had is ever removed, including when --force
overwrites and the encode then fails. If any output already exists the whole batch is refused
before any encoding starts, so you find out in the first second rather than at
the end; --force converts anyway. Two inputs that would produce the same output
are always refused, since one result would be lost either way. After encoding begins a failure is
reported and the run continues, and the exit status is non-zero if anything
failed.
USAGE
}

die() {
  printf 'convert-to: %s\n' "$1" >&2
  exit 1
}

warn() { printf 'convert-to: %s\n' "$1" >&2; }

# --force, --replace and --cover are ours and must not reach ffmpeg. They are
# pulled out wherever they appear, so they read naturally before or after the
# files. -R is free because ffmpeg has no -R; its -r and -i are taken.
force=0
replace=0
cover_file=''
declare -a argv=()
while (($#)); do
  case $1 in
  --force) force=1 ;;
  -R | --replace) replace=1 ;;
  --cover)
    (($# > 1)) || die '--cover needs a picture'
    cover_file=$2
    shift
    ;;
  --cover=*) cover_file=${1#--cover=} ;;
  *) argv+=("$1") ;;
  esac
  shift
done
set -- ${argv[@]+"${argv[@]}"}

case ${1-} in
-h | --help)
  usage
  exit 0
  ;;
'')
  usage >&2
  exit 64
  ;;
esac

target=$1
shift
case $target in
mp3 | mp4 | gif | jpg | png) ;;
*) die "cannot convert to '$target'; supported targets are mp3, mp4, gif, jpg and png" ;;
esac
if [[ -n $cover_file && $target != mp3 && $target != mp4 ]]; then
  die "--cover applies to mp3 and mp4, not $target"
fi

# Existing files are inputs and anything starting with a dash is an option, as
# is the word after one, since that is its value. What is left is a path that
# does not exist: a typo, which must not be passed on, because ffmpeg reads a
# bare token before the output as another output and would write a file there.
declare -a passthrough=() inputs=()
previous=''
for argument in "$@"; do
  if [[ -f $argument ]]; then
    inputs+=("$argument")
  elif [[ $argument == -* || $previous == -* ]]; then
    passthrough+=("$argument")
  else
    die "no such file: $argument"
  fi
  previous=$argument
done
((${#inputs[@]})) || die "no input files; try 'convert-to $target FILE'"

output_for() {
  local input=$1 directory='' base=$1 candidate
  # Strip the extension from the basename only: ${input%.*} cuts at the last dot
  # anywhere in the path, so an extensionless file inside a dotted directory
  # would land outside that directory.
  if [[ $input == */* ]]; then
    directory=${input%/*}/
    base=${input##*/}
  fi
  candidate="$directory${base%.*}.$target"
  if [[ $candidate == "$input" ]] && ((!replace)); then
    candidate="$directory${base%.*}.converted.$target"
  fi
  printf '%s' "$candidate"
}

# Every output is worked out before anything is encoded, so a collision costs a
# second rather than the length of the batch.
declare -A preexisting=() claimed_by=()
declare -a collisions=() duplicates=()
for input in "${inputs[@]}"; do
  output=$(output_for "$input")
  if [[ $output == "$input" ]]; then
    # -R rewriting a file in place: replacing it is what was asked for.
    preexisting[$output]=1
  elif [[ -e $output || -L $output ]]; then
    preexisting[$output]=1
    collisions+=("$output")
  fi
  if [[ -n ${claimed_by[$output]:-} ]]; then
    duplicates+=("${claimed_by[$output]} and $input both become $output")
  fi
  claimed_by[$output]=$input
done

# Two inputs wanting one output means a result is lost whatever happens, so
# --force does not apply: that is about files which were already there.
if ((${#duplicates[@]})); then
  for duplicate in "${duplicates[@]}"; do
    warn "$duplicate"
  done
  die 'refusing the whole batch; convert them separately'
fi

if ((!force)) && ((${#collisions[@]})); then
  for output in "${collisions[@]}"; do
    warn "$output already exists"
  done
  die "refusing the whole batch; remove them or pass --force"
fi

# ffmpeg reads a relative path with a colon in it, such as 'Song: Live.mkv', as
# a URL whose protocol is 'Song', and ImageMagick reads it as a format prefix.
# A leading ./ makes either tool see a plain file path.
tool_path() {
  if [[ $1 == /* || $1 == ./* ]]; then
    printf '%s' "$1"
  else
    printf './%s' "$1"
  fi
}

# codec_name,codec_type,attached_pic per stream. An attached picture is cover
# art rather than a video: it is what tells a tagged mp3 apart from a clip.
probe() {
  ffprobe -v error \
    -show_entries stream=codec_type,codec_name:stream_disposition=attached_pic \
    -of csv=p=0 -- "$(tool_path "$1")"
}

# The picture is checked once, before any encoding, like the outputs are.
cover_source=''
cover_codec=''
if [[ -n $cover_file ]]; then
  [[ -f $cover_file ]] || die "no such picture: $cover_file"
  cover_source=$(tool_path "$cover_file")
  cover_codec=$(probe "$cover_file" | awk -F, '$2 == "video" { print $1; exit }' || true)
  [[ -n $cover_codec ]] || die "$cover_file is not a picture"
  # A video or animation would become a video track, not a cover, and limiting
  # it with -frames:v stops the whole output, audio included, after one frame.
  cover_frames=$(magick identify -format '%n\n' "$cover_source" 2>/dev/null | head -n 1 || true)
  [[ $cover_frames == 1 ]] || die "$cover_file is not a single picture"
fi

failures=0
temporary_directory=''
temporary_output=''

cleanup_temporary_output() {
  if [[ -n $temporary_output ]]; then
    rm -f -- "$temporary_output"
    temporary_output=''
  fi
  if [[ -n $temporary_directory ]]; then
    rmdir -- "$temporary_directory" 2>/dev/null || true
    temporary_directory=''
  fi
}
trap cleanup_temporary_output EXIT

prepare_temporary_output() {
  local output=$1 output_directory='.'
  [[ $output != */* ]] || output_directory=${output%/*}
  temporary_directory=$(mktemp -d -- "$output_directory/.convert-to.XXXXXX") ||
    return 1
  temporary_output=$(tool_path "$temporary_directory/${output##*/}")
}

publish_temporary_output() {
  local input=$1 output=$2
  # An encoder can exit zero having written nothing; that is not a result, and
  # under -R it must never cost the original.
  [[ -s $temporary_output ]] || return 1
  if ((replace)); then
    chmod --reference="$input" -- "$temporary_output" || return 1
  fi
  if [[ -n ${preexisting[$output]:-} ]]; then
    # The old output remains untouched until this atomic replacement.
    mv -fT -- "$temporary_output" "$output" || return 1
  else
    # Refuse a file which appeared after preflight instead of racing it with
    # mv(1)'s default overwrite. `mv -n` reports success when it skips a move,
    # so the temporary file's continued existence is the refusal signal.
    mv -nT -- "$temporary_output" "$output" || return 1
    [[ ! -e $temporary_output ]] || return 1
  fi
  temporary_output=''
  rmdir -- "$temporary_directory" || return 1
  temporary_directory=''
}

for input in "${inputs[@]}"; do
  output=$(output_for "$input")
  source=$(tool_path "$input")
  streams=''
  [[ $target == jpg || $target == png ]] || streams=$(probe "$input" || true)

  video_codec=$(printf '%s\n' "$streams" | awk -F, '$2 == "video" && $3 == 0 { print $1; exit }')
  audio_codec=$(printf '%s\n' "$streams" | awk -F, '$2 == "audio" { print $1; exit }')
  cover=$(printf '%s\n' "$streams" | awk -F, '$2 == "video" && $3 == 1 { print $1; exit }')
  # The cover's position among the video streams, for a 0:v:N map. Streams are
  # listed in index order, so it is the number of video streams before it.
  cover_ordinal=$(printf '%s\n' "$streams" |
    awk -F, '$2 == "video" { if ($3 == 1) { print n + 0; exit } n++ }')

  declare -a ffmpeg_common=(ffmpeg -hide_banner -loglevel error -y)
  status=0

  case $target in
  mp3)
    if [[ -z $audio_codec ]]; then
      warn "$input has no audio stream"
      failures=$((failures + 1))
      continue
    fi
    if ! prepare_temporary_output "$output"; then
      warn "cannot create a temporary output beside $output"
      failures=$((failures + 1))
      continue
    fi
    # Cover art is carried across untouched as the mp3's attached picture. A
    # real video stream is not art and is dropped. ID3v2.3 because v2.4, the
    # default, is still unread by some players and by Windows Explorer.
    declare -a cover_input=() cover_map=(-vn)
    if [[ -n $cover_file ]]; then
      cover_input=(-i "$cover_source")
      cover_map=(-map '1:v:0')
      case $cover_codec in
      mjpeg | png) cover_map+=(-c:v copy) ;;
      *) cover_map+=(-c:v mjpeg -q:v 2) ;;
      esac
      cover_map+=(-disposition:v attached_pic -metadata:s:v 'comment=Cover (front)'
        -id3v2_version 3)
    elif [[ -n $cover ]]; then
      cover_map=(-map "0:v:$cover_ordinal" -c:v copy -disposition:v attached_pic
        -id3v2_version 3)
    fi
    # Only a new picture justifies touching an mp3, so its audio is copied.
    declare -a audio_codec_options=(-c:a libmp3lame -q:a 0 -ar 48000)
    if [[ -n $cover_file && $audio_codec == mp3 ]]; then
      audio_codec_options=(-c:a copy)
    fi
    "${ffmpeg_common[@]}" -i "$source" ${cover_input[@]+"${cover_input[@]}"} \
      -map '0:a:0' "${cover_map[@]}" -map_metadata 0 "${audio_codec_options[@]}" \
      ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
    ;;

  gif)
    if [[ -z $video_codec ]]; then
      warn "$input has no video stream to make a gif from"
      failures=$((failures + 1))
      continue
    fi
    if ! prepare_temporary_output "$output"; then
      warn "cannot create a temporary output beside $output"
      failures=$((failures + 1))
      continue
    fi
    palette=$(mktemp -t "convert-to-palette.XXXXXX.png")
    filters="fps=${GIF_FPS},scale=${GIF_WIDTH}:-1:flags=lanczos"
    # Two passes: a palette built from the whole clip, then the encode that
    # uses it. One pass quantises per frame and bands visibly.
    "${ffmpeg_common[@]}" -i "$source" -vf "$filters,palettegen=stats_mode=diff" \
      "$palette" &&
      "${ffmpeg_common[@]}" -i "$source" -i "$palette" \
        -lavfi "${filters}[x];[x][1:v]paletteuse=dither=bayer" \
        ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
    rm -f -- "$palette"
    ;;

  mp4)
    if [[ -n $video_codec && -n $cover_file ]]; then
      warn "$input is already a video; --cover is for audio"
      failures=$((failures + 1))
      continue
    elif [[ -n $video_codec ]]; then
      if ! prepare_temporary_output "$output"; then
        warn "cannot create a temporary output beside $output"
        failures=$((failures + 1))
        continue
      fi
      if [[ $video_codec == h264 && ( -z $audio_codec || $audio_codec == aac ) ]]; then
        # The codecs already fit mp4, so this is a container change. Safe here
        # and not in download, because the codecs were read first.
        "${ffmpeg_common[@]}" -i "$source" -map '0:v:0' -map '0:a?' -sn -dn \
          -c copy -movflags +faststart \
          ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
      else
        "${ffmpeg_common[@]}" -fflags +genpts -i "$source" \
          -map '0:v:0' -map '0:a?' -sn -dn \
          -vf "scale=ceil(iw*sar/2)*2:ceil(ih/2)*2,setsar=1,format=yuv420p" \
          -c:v libx264 -preset medium -crf 23 \
          -c:a aac -b:a 160k -ar 48000 -ac 2 \
          -movflags +faststart -max_muxing_queue_size 4096 \
          ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
      fi
    elif [[ -n $audio_codec && ( -n $cover || -n $cover_file ) ]]; then
      if ! prepare_temporary_output "$output"; then
        warn "cannot create a temporary output beside $output"
        failures=$((failures + 1))
        continue
      fi
      # One frame of the picture, extracted first, whatever format it came in.
      art_source=$source
      art_map="0:v:$cover_ordinal"
      if [[ -n $cover_file ]]; then
        art_source=$cover_source
        art_map='0:v:0'
      fi
      # The looped picture is cut at the audio's exact length. -shortest alone
      # overshoots badly: x264 buffers dozens of 1 fps frames, so a 60 second
      # song became a 117 second video, silent after the first minute.
      declare -a length=(-shortest)
      duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 \
        -- "$source" 2>/dev/null || true)
      if [[ $duration =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        length=(-t "$duration")
      fi
      artwork=$(mktemp -t "convert-to-cover.XXXXXX.jpg")
      still=$(tool_path "$temporary_directory/still.mp4")
      # The picture is then embedded again as the mp4's cover (its covr atom),
      # which is what Explorer, phones, Telegram and media servers show as the
      # thumbnail. That is a separate copy-only pass: in the encoding pass the
      # one-frame cover stream would end at once and -shortest would cut the
      # whole output to nothing.
      "${ffmpeg_common[@]}" -i "$art_source" -map "$art_map" -frames:v 1 "$artwork" &&
        "${ffmpeg_common[@]}" -loop 1 -framerate 1 -i "$artwork" -i "$source" \
          -map 0:v -map 1:a -map_metadata 1 \
          -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuv420p" \
          -c:v libx264 -tune stillimage -c:a aac -b:a 320k "${length[@]}" \
          ${passthrough[@]+"${passthrough[@]}"} "$still" &&
        "${ffmpeg_common[@]}" -i "$still" -i "$artwork" -map 0 -map 1 -c copy \
          -disposition:v:1 attached_pic -movflags +faststart \
          "$temporary_output" || status=$?
      rm -f -- "$artwork" "$still"
    elif [[ -n $audio_codec ]]; then
      warn "$input is audio with no cover art; nothing to show"
      failures=$((failures + 1))
      continue
    else
      warn "$input has no stream this can convert"
      failures=$((failures + 1))
      continue
    fi
    ;;
  jpg | png)
    # ImageMagick exits zero while writing name-0, name-1 and so on for each
    # frame of an animation or page of a document, so the one output promised
    # would not exist. The frame count is read first rather than guessed from
    # the extension, since webp, avif, heic and tiff can all hold several.
    frames=$(magick identify -format '%n\n' "$source" 2>/dev/null | head -n 1 || true)
    if [[ -z $frames ]]; then
      warn "$input is not an image ImageMagick can read"
      failures=$((failures + 1))
      continue
    fi
    if ((frames != 1)); then
      warn "$input holds $frames frames; a $target would split it into one file per frame"
      failures=$((failures + 1))
      continue
    fi
    if ! prepare_temporary_output "$output"; then
      warn "cannot create a temporary output beside $output"
      failures=$((failures + 1))
      continue
    fi
    declare -a image_options=(-auto-orient)
    if [[ $target == jpg ]]; then
      # JPEG has no alpha: without flattening, transparent pixels turn black.
      image_options+=(-background white -alpha remove -alpha off -quality "$JPEG_QUALITY")
    fi
    # ImageMagick expands %d and friends in an output name; %% is a literal %.
    magick "$source" "${image_options[@]}" \
      ${passthrough[@]+"${passthrough[@]}"} "${temporary_output//%/%%}" || status=$?
    ;;
  esac

  if ((status)); then
    warn "$input failed to convert"
    cleanup_temporary_output
    failures=$((failures + 1))
  elif ! publish_temporary_output "$input" "$output"; then
    warn "could not install the converted file at $output; the destination was not replaced"
    cleanup_temporary_output
    failures=$((failures + 1))
  elif ((replace)) && [[ $output != "$input" ]]; then
    if ! rm -f -- "$input"; then
      warn "converted $output but could not remove $input"
      failures=$((failures + 1))
    fi
  fi
done

if ((failures)); then
  die "$failures of ${#inputs[@]} file(s) failed"
fi
