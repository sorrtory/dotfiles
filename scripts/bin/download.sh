#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: download [--as TYPE|EXTENSION] [--using BACKEND] URL... [-- BACKEND_OPTIONS...]

The URL picks a downloader. With no --as, use its normal result.
Use --as to request a different result where that downloader supports it:

  original                           backend's published media, unchanged
  audio                              best audio stream, untouched
  mp3 m4a opus flac wav aac          extracted and encoded
  alac vorbis ogg
  video                              best video, untouched
  mp4 mkv webm mov                   recoded
  jpg png                            still images re-encoded
  file                               any plain file

Known sites include YouTube/Vimeo/TikTok/Twitch (video), SoundCloud (audio),
Spotify (mp3), Pinterest/Instagram/Imgur/Pixiv and other galleries,
Google Drive (gdown), and Yandex.Disk (aria2c after public-link resolution).
Direct file URLs use aria2c.
An unknown site opens a backend picker in a terminal. In a script, use --using.

  download 'https://youtu.be/...'
  download --as mp3 'https://youtu.be/...'
  download --as jpg 'https://www.pinterest.com/pin/...'
  download --using gallery-dl 'https://example.org/post/...'
  download --as mp4 URL -- --playlist-items 1-3

Backend options go after -- and are passed untouched. --cookies FILE and
--cookies-from-browser BROWSER are translated for the chosen backend.
Files land in the current directory. Use backend options for destinations:
-P for yt-dlp, -D for gallery-dl, -d for aria2c, -O for gdown.

--spotify-meta sends a YouTube link to spotdl for Spotify tags. spotdl's
default output is mp3; --as can select another supported audio extension.

Downloads go through the local proxy in $PROXY. For a direct run:

  PROXY= download --as mp4 URL

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

as=''
using=''
spotify_meta=0
cookies=''
browser=''
declare -a urls=() backend_options=() rest=()
while (($#)); do
  case $1 in
  -h | --help) usage; exit 0 ;;
  --as | --using | --cookies | --cookies-from-browser)
    [[ $# -ge 2 && -n $2 ]] || die "$1 needs a value"
    case $1 in
    --as) as=$2 ;;
    --using) using=$2 ;;
    --cookies) cookies=$2 ;;
    --cookies-from-browser) browser=$2 ;;
    esac
    shift 2
    ;;
  --as=*) as=${1#*=}; [[ -n $as ]] || die '--as needs a value'; shift ;;
  --using=*) using=${1#*=}; [[ -n $using ]] || die '--using needs a value'; shift ;;
  --cookies=*) cookies=${1#*=}; [[ -n $cookies ]] || die '--cookies needs a file'; shift ;;
  --cookies-from-browser=*) browser=${1#*=}; [[ -n $browser ]] || die '--cookies-from-browser needs a browser'; shift ;;
  --spotify-meta) spotify_meta=1; shift ;;
  --)
    shift
    backend_options=("$@")
    break
    ;;
  -*) die "unknown option '$1'; put backend options after --" ;;
  *) urls+=("$1"); shift ;;
  esac
done

((${#urls[@]})) || die 'no URL given; try download URL'
[[ -z $cookies || -z $browser ]] || die 'choose either --cookies or --cookies-from-browser'

case $as in
'' | original | audio | video | file | mp3 | m4a | opus | flac | wav | aac | alac | vorbis | ogg | mp4 | mkv | webm | mov | jpg | png) ;;
gif) die "gif is a convert-to target: try 'download URL' then 'convert-to gif FILE'" ;;
*) die "unknown --as value '$as'; run 'download --help' for the list" ;;
esac
case $using in
'' | yt-dlp | gallery-dl | aria2c | spotdl | gdown) ;;
*) die "unknown backend '$using'; choose yt-dlp, gallery-dl, aria2c, spotdl or gdown" ;;
esac

# Match a listed domain or one of its subdomains, never a lookalike suffix.
host_matches_any() {
  local host=$1 domain
  shift
  for domain in "$@"; do
    [[ $host == "$domain" || $host == *".$domain" ]] && return 0
  done
  return 1
}

# This table expresses the operator's default result for a source, not a
# duplicate of either backend's supported-sites list. Unknown pages are never
# treated as plain files: that could silently save an HTML error page.
guess_source() {
  local url=$1 host path extension
  guessed_backend='' guessed_as=''
  case $url in
  spotify:* | saved) guessed_backend=spotdl; guessed_as=mp3; return ;;
  esac
  [[ $url =~ ^https?://([^/:?#]+) ]] || return 0
  host=${BASH_REMATCH[1],,}

  if host_matches_any "$host" spotify.com spotify.link; then
    guessed_backend=spotdl; guessed_as=mp3
  elif host_matches_any "$host" youtube.com youtu.be youtube-nocookie.com \
    vimeo.com tiktok.com twitch.tv; then
    guessed_backend=yt-dlp; guessed_as=video
  elif host_matches_any "$host" soundcloud.com on.soundcloud.com; then
    guessed_backend=yt-dlp; guessed_as=audio
  elif host_matches_any "$host" pinterest.com pin.it instagram.com imgur.com \
    pixiv.net e621.net danbooru.donmai.us artstation.com deviantart.com \
    flickr.com; then
    guessed_backend=gallery-dl; guessed_as=original
  elif host_matches_any "$host" drive.google.com docs.google.com; then
    guessed_backend=gdown; guessed_as='file'
  elif host_matches_any "$host" disk.yandex.ru disk.yandex.com yadi.sk; then
    guessed_backend=aria2c; guessed_as='file'
  else
    path=${url%%[?#]*}
    extension=${path##*.}
    case ${extension,,} in
    jpg | jpeg | png | gif | webp | avif | pdf | zip | 7z | tar | gz | \
      mp3 | m4a | flac | mp4 | mkv | webm)
      guessed_backend=aria2c; guessed_as='file' ;;
    esac
  fi
}

pick_backend() {
  [[ -t 0 && -t 2 ]] ||
    die "cannot guess '$1' without a terminal; use --using yt-dlp, gallery-dl or aria2c"
  local choice
  choice=$(printf '%s\n' 'yt-dlp  video/audio' 'gallery-dl  galleries/posts' 'aria2c  plain file' |
    fzf --height=8 --layout=reverse --no-multi --prompt='Downloader > ') || exit 130
  [[ -n $choice ]] || exit 130
  case $choice in
  yt-dlp*) guessed_backend=yt-dlp; guessed_as=video ;;
  gallery-dl*) guessed_backend=gallery-dl; guessed_as=original ;;
  aria2c*) guessed_backend=aria2c; guessed_as='file' ;;
  esac
}

backend=''
default_as=''
for url in "${urls[@]}"; do
  guess_source "$url"
  source_backend=$guessed_backend
  if [[ -n $using ]]; then
    guessed_backend=$using
    case $using in
    yt-dlp) [[ $source_backend == yt-dlp ]] || guessed_as=video ;;
    gallery-dl) guessed_as=original ;;
    aria2c | gdown) guessed_as='file' ;;
    spotdl) guessed_as=mp3 ;;
    esac
  elif ((spotify_meta)); then
    guessed_backend=spotdl; guessed_as=mp3
  elif [[ -z $guessed_backend ]]; then
    pick_backend "$url"
  fi
  if [[ -n $backend && ( $backend != "$guessed_backend" || ( -z $as && $default_as != "$guessed_as" ) ) ]]; then
    die 'URLs need different downloaders or defaults; run them separately or set --as and --using'
  fi
  backend=$guessed_backend
  default_as=$guessed_as
done
[[ -n $as ]] || as=$default_as

case $backend in
yt-dlp)
  case $as in
  original | audio | video | mp3 | m4a | opus | flac | wav | aac | alac | vorbis | ogg | mp4 | mkv | webm | mov) ;;
  *) die "yt-dlp cannot produce --as $as; choose an audio or video result" ;;
  esac ;;
gallery-dl)
  case $as in
  original | jpg | png) ;;
  *) die "gallery-dl cannot produce --as $as; use original, jpg or png" ;;
  esac ;;
aria2c | gdown)
  [[ $as == file || $as == original ]] || die "$backend keeps the source file; use --as file or omit --as" ;;
spotdl)
  case $as in
  mp3 | flac | ogg | opus | m4a | wav) ;;
  *) die "spotdl supports --as mp3, flac, ogg, opus, m4a or wav" ;;
  esac ;;
esac

case $as in
audio | mp3 | m4a | opus | flac | wav | aac | alac | vorbis | ogg) kind=audio ;;
original | video | mp4 | mkv | webm | mov) kind=video ;;
jpg | png) kind=image ;;
file) kind='file' ;;
esac
case $as in
mp3 | m4a | opus | flac | wav | aac | alac | vorbis | ogg | mp4 | mkv | webm | mov | jpg | png) format=$as ;;
*) format='' ;;
esac

if [[ -n $browser ]]; then
  case $backend in
  aria2c | spotdl) die "$backend cannot read a browser's cookie store; export it and pass --cookies FILE" ;;
  esac
  rest+=(--cookies-from-browser "$browser")
fi
if [[ -n $cookies ]]; then
  case $backend in
  aria2c) rest+=(--load-cookies "$cookies") ;;
  spotdl) rest+=(--cookie-file "$cookies") ;;
  *) rest+=(--cookies "$cookies") ;;
  esac
fi
rest+=("${backend_options[@]}" "${urls[@]}")

if [[ $backend == gdown && ${#urls[@]} -ne 1 ]]; then
  die 'gdown accepts one URL per invocation'
fi

printf 'download: %s via %s\n' "$as" "$backend" >&2

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

# The public-link resolution follows wldhx/yadisk-direct's approach:
# https://github.com/wldhx/yadisk-direct/blob/master/wldhx/yadisk_direct/main.py
# A Yandex.Disk share page is not the file URL aria2c needs. Resolve only
# recognized public share links, leaving ordinary file URLs and options alone.
# curl encodes the whole link as public_key; interpolation into the API URL
# would break links containing their own query string.
resolve_yandex_link() {
  local response href
  if ! response=$(env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
    -u http_proxy -u https_proxy -u all_proxy \
    curl -q --fail --silent --show-error --max-time 20 --proxy "$proxy" \
      --get --data-urlencode "public_key=$1" \
      'https://cloud-api.yandex.net/v1/disk/public/resources/download'); then
    die "could not resolve Yandex.Disk link: $1"
  fi
  if ! href=$(jq -er '.href | select(type == "string" and startswith("https://"))' <<<"$response"); then
    die "Yandex.Disk did not return a download URL for: $1"
  fi
  printf '%s' "$href"
}

if [[ $backend == aria2c ]]; then
  declare -a resolved=()
  yandex_link=0
  for argument in "${rest[@]}"; do
    case $argument in
    https://disk.yandex.ru/* | https://disk.yandex.com/* | https://yadi.sk/*)
      resolved+=("$(resolve_yandex_link "$argument")")
      yandex_link=1
      ;;
    *) resolved+=("$argument") ;;
    esac
  done
  rest=("${resolved[@]}")
fi

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
  # The resolved URL's path is opaque; use the server's suggested filename.
  if ((yandex_link)); then
    command+=(--content-disposition=true)
  fi
  ;;
spotdl)
  command=(spotdl)
  [[ -z $proxy ]] || command+=(--proxy "$proxy")
  [[ -z $format ]] || command+=(--format "$format")
  ;;
gdown)
  command=(gdown)
  [[ -z $proxy ]] || command+=(--proxy "$proxy")
  ;;
esac

if [[ -n $proxy ]]; then
  # spotdl's --proxy covers only the audio download. Its lookups — Spotify
  # through spotapi, YouTube Music through ytmusicapi — read the environment
  # instead, and a desktop launcher's environment may carry no proxy at all,
  # so PROXY is handed to them there. Both lookups are region-blocked here.
  if [[ $backend == spotdl ]]; then
    exec env HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy" \
      http_proxy="$proxy" https_proxy="$proxy" \
      "${command[@]}" ${rest[@]+"${rest[@]}"}
  fi
  exec "${command[@]}" ${rest[@]+"${rest[@]}"}
fi

# An empty PROXY promises a direct run. yt-dlp and aria2c honour an empty proxy
# option and gallery-dl is told to ignore the environment, but spotdl has no
# such spelling and reads these variables itself, as does the yt-dlp it drives.
exec env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
  -u http_proxy -u https_proxy -u all_proxy \
  "${command[@]}" ${rest[@]+"${rest[@]}"}
