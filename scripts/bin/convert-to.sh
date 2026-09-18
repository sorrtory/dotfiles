#!/usr/bin/env bash
set -euo pipefail

readonly GIF_FPS=15
readonly GIF_WIDTH=480

usage() {
  cat <<'USAGE'
Usage: convert-to <mp3|mp4|gif> [ffmpeg options] FILE...

Convert files that are already on disk. To fetch something, use download,
which lets the downloader do its own conversion while it still holds the
source streams and metadata.

  convert-to mp3 *.m4a          encode the audio to mp3
  convert-to mp4 clip.mkv       remux when the codecs already fit, else transcode
  convert-to mp4 song.mp3       cover art plus audio, as a still video
  convert-to gif clip.mp4       two-pass palette, 15 fps, 480px wide

The output sits beside the input under the same name. Converting a file into
its own name writes NAME.converted.EXT instead.

Nothing you already had is ever removed, including when --force overwrites and
the encode then fails. If any output already exists the whole batch is refused
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

force=0
declare -a argv=()
for argument in "$@"; do
  if [[ $argument == --force ]]; then
    force=1
  else
    argv+=("$argument")
  fi
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
mp3 | mp4 | gif) ;;
*) die "cannot convert to '$target'; supported targets are mp3, mp4 and gif" ;;
esac

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
  if [[ $candidate == "$input" ]]; then
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
  if [[ -e $output || -L $output ]]; then
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

# codec_name,codec_type,attached_pic per stream. An attached picture is cover
# art rather than a video: it is what tells a tagged mp3 apart from a clip.
probe() {
  ffprobe -v error \
    -show_entries stream=codec_type,codec_name:stream_disposition=attached_pic \
    -of csv=p=0 -- "$1"
}

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
  temporary_output="$temporary_directory/${output##*/}"
}

publish_temporary_output() {
  local output=$1
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
  streams=$(probe "$input" || true)

  video_codec=$(printf '%s\n' "$streams" | awk -F, '$2 == "video" && $3 == 0 { print $1; exit }')
  audio_codec=$(printf '%s\n' "$streams" | awk -F, '$2 == "audio" { print $1; exit }')
  cover=$(printf '%s\n' "$streams" | awk -F, '$2 == "video" && $3 == 1 { print $1; exit }')

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
    "${ffmpeg_common[@]}" -i "$input" -vn -c:a libmp3lame -q:a 0 -ar 48000 \
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
    "${ffmpeg_common[@]}" -i "$input" -vf "$filters,palettegen=stats_mode=diff" \
      "$palette" &&
      "${ffmpeg_common[@]}" -i "$input" -i "$palette" \
        -lavfi "${filters}[x];[x][1:v]paletteuse=dither=bayer" \
        ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
    rm -f -- "$palette"
    ;;

  mp4)
    if [[ -n $video_codec ]]; then
      if ! prepare_temporary_output "$output"; then
        warn "cannot create a temporary output beside $output"
        failures=$((failures + 1))
        continue
      fi
      if [[ $video_codec == h264 && ( -z $audio_codec || $audio_codec == aac ) ]]; then
        # The codecs already fit mp4, so this is a container change. Safe here
        # and not in download, because the codecs were read first.
        "${ffmpeg_common[@]}" -i "$input" -map '0:v:0' -map '0:a?' -sn -dn \
          -c copy -movflags +faststart \
          ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
      else
        "${ffmpeg_common[@]}" -fflags +genpts -i "$input" \
          -map '0:v:0' -map '0:a?' -sn -dn \
          -vf "scale=ceil(iw*sar/2)*2:ceil(ih/2)*2,setsar=1,format=yuv420p" \
          -c:v libx264 -preset medium -crf 23 \
          -c:a aac -b:a 160k -ar 48000 -ac 2 \
          -movflags +faststart -max_muxing_queue_size 4096 \
          ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
      fi
    elif [[ -n $audio_codec && -n $cover ]]; then
      if ! prepare_temporary_output "$output"; then
        warn "cannot create a temporary output beside $output"
        failures=$((failures + 1))
        continue
      fi
      artwork=$(mktemp -t "convert-to-cover.XXXXXX.jpg")
      "${ffmpeg_common[@]}" -i "$input" -map 0:v:0 -frames:v 1 "$artwork" &&
        "${ffmpeg_common[@]}" -loop 1 -framerate 1 -i "$artwork" -i "$input" \
          -map 0:v -map 1:a -map_metadata 1 \
          -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2,format=yuv420p" \
          -c:v libx264 -tune stillimage -c:a aac -b:a 320k \
          -shortest -movflags +faststart \
          ${passthrough[@]+"${passthrough[@]}"} "$temporary_output" || status=$?
      rm -f -- "$artwork"
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
  esac

  if ((status)); then
    warn "$input failed to convert"
    cleanup_temporary_output
    failures=$((failures + 1))
  elif ! publish_temporary_output "$output"; then
    warn "could not install the converted file at $output; the destination was not replaced"
    cleanup_temporary_output
    failures=$((failures + 1))
  fi
done

if ((failures)); then
  die "$failures of ${#inputs[@]} file(s) failed"
fi
