#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: download <type|extension> [backend options] URL...

Fetch media. The single argument is either a type, which downloads in the
source's own format, or an extension, which asks for that format:

  audio                              best audio stream, untouched
  mp3 m4a opus flac wav aac          extracted and encoded
  alac vorbis ogg
  video                              best video, untouched
  mp4 mkv webm mov                   recoded
  image                              exactly as published
  jpg png                            still images re-encoded
  file                               any plain file

The type chooses the backend: yt-dlp for audio and video, gallery-dl for
images, aria2c for files, spotdl for Spotify. Everything else you pass is
handed to that backend untouched, so its own options keep working:

  download mp4 --playlist-items 1-3 URL
  download jpg --range 1-5 --cookies-from-browser firefox URL

Files land in the current directory. Use the backend's own option to put them
elsewhere: -P for yt-dlp, -D for gallery-dl, -d for aria2c.

Spotify links and the query 'saved' always go to spotdl, because nothing else
reads them. Spotify has no untouched source format, so use an explicit audio
extension for it. --spotify-meta sends a YouTube link there too, to get
Spotify's tags on a track that is only on YouTube.

Downloads go through the local proxy in $PROXY. For a direct run:

  PROXY= download mp4 URL

gif is not here: a one-pass GIF bands visibly, so use convert-to gif on a
downloaded clip instead.
USAGE
}

die() {
  printf 'download: %s\n' "$1" >&2
  exit 1
}

# Builds the shell snippet gallery-dl runs once per downloaded file, with the
# path substituted for {} and shell-quoted. gallery-dl has no image
# post-processor of its own, so driving ImageMagick from here is upstream's
# own documented answer.
#
# The original is removed only after a conversion that both succeeded and wrote
# a non-empty file. Conversion goes to a sibling temporary file, and an atomic
# hard-link claims the final name without replacing anything already there. A
# failure warns and returns non-zero, which gallery-dl treats as a warning, so
# one bad file does not end the run. Formats outside the list are left alone. So
# is anything holding more than one frame: webp, avif, heic and tiff all can,
# and ImageMagick exits 0 while writing name-0, name-1 and so on, leaving the
# single name promised absent and strays gallery-dl knows nothing about beside
# it. Extension alone cannot tell, so the frame count is read.
#
# Single quotes throughout: every expansion belongs to the shell gallery-dl
# starts, not to this one.
# shellcheck disable=SC2016
converter() {
  local target=$1 sources=$2 quality=''
  if [[ $target == jpg ]]; then
    quality=' -quality 95'
  fi
  printf '%s' '
  source_path={}
  extension=$(printf %s "${source_path##*.}" | tr "[:upper:]" "[:lower:]")

  case $extension in
  '"$sources"') ;;
  *) exit 0 ;;
  esac

  frames=$(magick identify -format "%n\n" "$source_path" 2>/dev/null | head -1)
  case ${frames:-1} in
  1) ;;
  *) exit 0 ;;
  esac

  target_path="${source_path%.*}.'"$target"'"
  if [ -e "$target_path" ] || [ -L "$target_path" ]; then
    printf "download: kept %s, target already exists: %s\n" \
      "$source_path" "$target_path" >&2
    exit 1
  fi

  temp_path=$(mktemp -- "$target_path.tmp.XXXXXX.'"$target"'") || exit 1
  trap '\''rm -f -- "$temp_path"'\'' EXIT HUP INT TERM
  if magick "$source_path"'"$quality"' "$temp_path" && [ -s "$temp_path" ]
  then
    chmod --reference="$source_path" "$temp_path" || exit 1
    if ln -- "$temp_path" "$target_path"; then
      rm -f -- "$temp_path"
      trap - EXIT HUP INT TERM
      rm -f -- "$source_path"
    else
      printf "download: kept %s, target already exists: %s\n" \
        "$source_path" "$target_path" >&2
      exit 1
    fi
  else
    printf "download: kept %s, conversion failed\n" "$source_path" >&2
    exit 1
  fi
'
}

# --spotify-meta is ours and must not reach a backend. It is pulled out
# wherever it appears, so it reads naturally before or after the type.
spotify_meta=0
declare -a argv=()
for argument in "$@"; do
  if [[ $argument == --spotify-meta ]]; then
    spotify_meta=1
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

what=$1
shift

case $what in
audio) kind=audio format='' ;;
mp3 | m4a | opus | flac | wav | aac | alac | vorbis | ogg) kind=audio format=$what ;;
video) kind=video format='' ;;
mp4 | mkv | webm | mov) kind=video format=$what ;;
image) kind=image format='' ;;
jpg | png) kind=image format=$what ;;
file) kind=file format='' ;;
gif)
  die "gif is a convert-to target, not a download one: try 'download mp4 URL' then 'convert-to gif FILE'"
  ;;
*)
  die "unknown type or extension '$what'; run 'download --help' for the list"
  ;;
esac

(($#)) || die "no URL given; try 'download $what URL'"

# Spotify is the one thing a URL has to be inspected for, because yt-dlp has no
# extractor for it at all.
spotify=$spotify_meta
for argument in "$@"; do
  case $argument in
  https://open.spotify.com/* | http://open.spotify.com/* | spotify:*)
    spotify=1
    ;;
  esac
done

# Backend options precede their source in this command's documented syntax.
# Restrict spotDL's bare `saved` query to the final argument so an option value
# such as `--output saved URL` cannot change the backend.
[[ ${!#} == saved ]] && spotify=1

if ((spotify)); then
  [[ $kind == audio ]] ||
    die "Spotify carries audio only; ask for an audio type or extension"
  case $format in
  '') die "Spotify has no untouched audio source; choose mp3, flac, ogg, opus, m4a or wav" ;;
  mp3 | flac | ogg | opus | m4a | wav) ;;
  *) die "Spotify cannot give you $format; it supports mp3, flac, ogg, opus, m4a and wav" ;;
  esac
  backend=spotdl
else
  case $kind in
  audio | video) backend=yt-dlp ;;
  image) backend=gallery-dl ;;
  file) backend=aria2c ;;
  esac
fi

# yt-dlp and gallery-dl already agree on --cookies and --cookies-from-browser,
# so those pass straight through. Only the other two need translating.
declare -a rest=()
while (($#)); do
  case $1 in
  --cookies=*)
    jar=${1#*=}
    case $backend in
    aria2c) rest+=(--load-cookies "$jar") ;;
    spotdl) rest+=(--cookie-file "$jar") ;;
    *) rest+=("$1") ;;
    esac
    shift
    ;;
  --cookies-from-browser=*)
    case $backend in
    aria2c | spotdl)
      die "$backend cannot read a browser's cookie store; export them to a file and pass --cookies FILE"
      ;;
    esac
    rest+=("$1")
    shift
    ;;
  --cookies)
    [[ $# -ge 2 ]] || die '--cookies needs a file'
    case $backend in
    aria2c) rest+=(--load-cookies "$2") ;;
    spotdl) rest+=(--cookie-file "$2") ;;
    *) rest+=(--cookies "$2") ;;
    esac
    shift 2
    ;;
  --cookies-from-browser)
    case $backend in
    aria2c | spotdl)
      die "$backend cannot read a browser's cookie store; export them to a file and pass --cookies FILE"
      ;;
    esac
    [[ $# -ge 2 ]] || die '--cookies-from-browser needs a browser'
    rest+=("$1" "$2")
    shift 2
    ;;
  *)
    rest+=("$1")
    shift
    ;;
  esac
done

# yt-dlp is the one backend Nix does not provide: it is the bootstrap-installed
# release binary, so that it can keep updating itself. A login shell has
# ~/.local/bin on PATH, but a desktop launcher's environment does not, so fall
# back to the path the bootstrap phase owns before giving up.
resolve_yt_dlp() {
  if command -v yt-dlp >/dev/null 2>&1; then
    printf 'yt-dlp'
  elif [[ -x "$HOME/.local/bin/yt-dlp" ]]; then
    printf '%s' "$HOME/.local/bin/yt-dlp"
  else
    die "yt-dlp is not installed; run './scripts/bootstrap.sh install yt-dlp'"
  fi
}

proxy=${PROXY:-}
declare -a command=()

case $backend in
yt-dlp)
  # Always --recode-video, never --remux-video: remuxing fails outright when
  # the target container does not support the codec, which is every VP9 or
  # Opus stream. Recoding is a no-op when the source already fits.
  command=("$(resolve_yt_dlp)" --proxy "$proxy")
  if [[ $kind == audio ]]; then
    command+=(-x)
    # yt-dlp has no 'ogg'; the Vorbis-in-Ogg it produces is spelled vorbis.
    [[ -n $format ]] && command+=(--audio-format "${format/#ogg/vorbis}")
  elif [[ -n $format ]]; then
    command+=(--recode-video "$format")
  fi
  ;;
gallery-dl)
  # An empty --proxy does not mean a direct connection here, unlike yt-dlp:
  # gallery-dl treats it as unset and reads the environment instead. Turning
  # that off is what actually makes PROXY= direct.
  command=(gallery-dl --proxy "$proxy")
  [[ -n $proxy ]] || command+=(-o proxy-env=false)
  case $format in
  jpg) command+=(--exec "$(converter jpg 'png|webp|bmp|tif|tiff|avif|jxl|heic|heif')") ;;
  # Deliberately not from a lossy source: re-encoding one into a lossless
  # container yields a larger file and recovers nothing.
  png) command+=(--exec "$(converter png 'webp|avif|jxl|heic|heif')") ;;
  esac
  ;;
aria2c)
  # aria2's own default is one connection per server, which would make it no
  # better than wget. Without force-sequential it also treats command-line URLs
  # as mirrors of one file rather than independent downloads. An empty
  # --all-proxy overrides a proxy, as documented.
  command=(aria2c --all-proxy "$proxy" -x8 -s8 --continue --force-sequential=true)
  ;;
spotdl)
  command=(spotdl)
  [[ -z $proxy ]] || command+=(--proxy "$proxy")
  [[ -z $format ]] || command+=(--format "$format")
  ;;
esac

if [[ -n $proxy ]]; then
  exec "${command[@]}" ${rest[@]+"${rest[@]}"}
fi

# An empty PROXY promises a direct run. yt-dlp and aria2c honour an empty proxy
# option and gallery-dl is told to ignore the environment, but spotdl has no
# such spelling and reads these variables itself, as does the yt-dlp it drives.
exec env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
  -u http_proxy -u https_proxy -u all_proxy \
  "${command[@]}" ${rest[@]+"${rest[@]}"}
