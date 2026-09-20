#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# The session's own proxy would otherwise stand in for the test default below.
unset PROXY HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy

# Every backend is a recorder: it writes its own name and each argument on its
# own line, so an assertion reads exactly what the dispatcher built. Nothing
# here touches the network.
mkdir -p "$root/bin"
for backend in yt-dlp gallery-dl aria2c spotdl; do
  cat >"$root/bin/$backend" <<EOF
#!/usr/bin/env bash
{ printf '$backend\n'; printf '%s\n' "\$@"; } >"\$RECORDING"
printf '%s\n' "\${HTTPS_PROXY-unset}" >"\$RECORDING.env"
EOF
  chmod +x "$root/bin/$backend"
done

# Runs the subject with the mocks first on PATH and the recording emptied.
# PROXY is set unless the caller overrides it, because the interesting default
# is "a proxy is configured".
run() {
  : >"$root/recording"
  RECORDING=$root/recording PATH="$root/bin:$PATH" PROXY=${PROXY-http://p:3128} \
    bash "$repo/scripts/bin/download.sh" "$@"
}

recorded() { tr '\n' ' ' <"$root/recording"; }

# --- the type argument selects the backend -------------------------------

run audio URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 -x URL '* ]] ||
  fail "bare audio should extract without a format: $(recorded)"

run mp3 URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 -x --audio-format mp3 URL '* ]] ||
  fail "mp3 should name the audio format: $(recorded)"

run video URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 URL '* ]] ||
  fail "bare video should neither extract nor recode: $(recorded)"

run mp4 URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 --recode-video mp4 URL '* ]] ||
  fail "mp4 should recode, never remux: $(recorded)"
[[ $(recorded) != *'--remux-video'* ]] ||
  fail 'remuxing fails outright when the codecs do not fit the container'

run image URL >/dev/null
[[ $(recorded) == 'gallery-dl --proxy http://p:3128 URL '* ]] ||
  fail "bare image should publish as downloaded: $(recorded)"
[[ $(recorded) != *'--exec'* ]] ||
  fail 'bare image must not run a converter'

run jpg URL >/dev/null
[[ $(recorded) == 'gallery-dl --proxy http://p:3128 --exec '* ]] ||
  fail "jpg should convert through gallery-dl's exec: $(recorded)"

run file URL >/dev/null
[[ $(recorded) == 'aria2c --all-proxy http://p:3128 -x8 -s8 --continue --force-sequential=true URL '* ]] ||
  fail "file should reach aria2c with real parallelism: $(recorded)"

run file URL1 URL2 >/dev/null
[[ $(recorded) == *'--force-sequential=true URL1 URL2 '* ]] ||
  fail "multiple file URLs must be separate downloads, not mirrors: $(recorded)"

# --- the conversion snippets --------------------------------------------

run jpg URL >/dev/null
grep -q 'png|webp|bmp|tif|tiff|avif|jxl|heic|heif' "$root/recording" ||
  fail 'jpg should convert every still format it can'
grep -q 'jpg' "$root/recording" || fail 'jpg snippet should target jpg'

run png URL >/dev/null
grep -q 'webp|avif|jxl|heic|heif' "$root/recording" ||
  fail 'png should normalise the lossless-ish formats'
grep -qE '\bpng\|' "$root/recording" &&
  fail 'png must not re-encode JPEG or PNG sources into PNG'
grep -q 'jpe\?g' "$root/recording" &&
  fail 'png must leave JPEG alone rather than inflating it'

# --- format vocabulary ---------------------------------------------------

run ogg URL >/dev/null
[[ $(recorded) == *'--audio-format vorbis'* ]] ||
  fail "yt-dlp spells ogg 'vorbis': $(recorded)"

run gif URL 2>/dev/null && fail 'gif is a convert-to target, not a download one'
[[ ! -s $root/recording ]] || fail 'a rejected type must not reach a backend'

output=$(run gif URL 2>&1 || true)
[[ $output == *'convert-to'* ]] || fail "gif should point at convert-to: $output"

output=$(run mpeg URL 2>&1 || true)
[[ $output == *'mpeg'* ]] || fail "an unknown type should name what was given: $output"

# --- Spotify routing -----------------------------------------------------

run mp3 'https://open.spotify.com/track/abc' >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail "a Spotify URL has no other backend: $(recorded)"
[[ $(recorded) == *'--format mp3'* ]] || fail "spotdl spells it --format: $(recorded)"

run mp3 'spotify:track:abc' >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail 'a spotify: URI should route to spotdl'

run mp3 saved >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail "'saved' means liked songs, which only spotdl reads"

run mp3 --user-auth saved >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail "a valueless option before 'saved' must not hide the spotdl query"

output=$(run audio 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'choose mp3'* ]] ||
  fail "Spotify audio should require an explicit output format: $output"
[[ ! -s $root/recording ]] || fail 'formatless Spotify audio must not reach spotdl'

run mp3 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'yt-dlp '* ]] ||
  fail "YouTube must not be matched against Spotify by default: $(recorded)"

run --spotify-meta mp3 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail '--spotify-meta should opt a YouTube URL into Spotify tagging'
[[ $(recorded) != *'--spotify-meta'* ]] ||
  fail 'the flag is ours and must not leak to the backend'

run mp3 --spotify-meta 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail '--spotify-meta should be positional-agnostic'

output=$(run aac 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'mp3'* && $output == *'flac'* ]] ||
  fail "an impossible Spotify format should name the possible ones: $output"
[[ ! -s $root/recording ]] || fail 'an impossible format must not reach spotdl'

run aac 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'yt-dlp '*'--audio-format aac'* ]] ||
  fail 'aac is fine everywhere except Spotify'

output=$(run mp4 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'audio'* ]] || fail "Spotify has no video: $output"

# --- proxy ---------------------------------------------------------------

PROXY= run mp4 URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy  --recode-video mp4 URL '* ]] ||
  fail "an empty PROXY should ask yt-dlp for a direct connection: $(recorded)"
[[ $(recorded) != *'http://p:3128'* ]] ||
  fail 'an empty PROXY must not produce a proxy address'

PROXY= run jpg URL >/dev/null
[[ $(recorded) == *'proxy-env=false'* ]] ||
  fail "gallery-dl ignores an empty --proxy and falls back to the environment: $(recorded)"

PROXY= run file URL >/dev/null
[[ $(recorded) == 'aria2c --all-proxy  '* ]] ||
  fail "aria2c overrides a previous proxy with an empty value: $(recorded)"

# --- passthrough ---------------------------------------------------------

run mp4 --playlist-items 1-3 URL >/dev/null
[[ $(recorded) == *'--playlist-items 1-3 URL '* ]] ||
  fail "backend options should survive in order: $(recorded)"

run jpg --range 1-5 --cookies-from-browser firefox URL >/dev/null
[[ $(recorded) == *'--range 1-5 --cookies-from-browser firefox URL '* ]] ||
  fail 'gallery-dl options should pass through untouched'

run file --cookies "$root/jar" URL >/dev/null
[[ $(recorded) == *'--load-cookies '*'/jar'* ]] ||
  fail "aria2c spells a cookie jar --load-cookies: $(recorded)"

run mp3 --cookies "$root/jar" 'https://open.spotify.com/track/a' >/dev/null
[[ $(recorded) == *'--cookie-file '*'/jar'* ]] ||
  fail "spotdl spells it --cookie-file: $(recorded)"

output=$(run mp3 --cookies-from-browser firefox 'https://open.spotify.com/t/a' 2>&1 || true)
[[ $output == *'--cookies'* ]] ||
  fail "spotdl cannot read a browser's cookies and should say so: $output"

# --- the environment is cleared for a direct run -------------------------

# spotdl has no empty-proxy spelling and reads these itself, as does the yt-dlp
# it drives, so PROXY= has to clear them or proxy-on would still tunnel.
HTTPS_PROXY=http://leak:3128 PROXY= run mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'unset' ]] ||
  fail "a direct run must not leave a proxy in spotdl's environment: $(<"$root/recording.env")"

# spotdl's metadata lookups read only the environment, and region blocks make
# them fail direct, so a proxied run puts PROXY there — over whatever the
# caller's environment held, or held nothing at all.
HTTPS_PROXY=http://stale:3128 run mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'http://p:3128' ]] ||
  fail "a proxied spotdl run should see PROXY in its environment: $(<"$root/recording.env")"

run mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'http://p:3128' ]] ||
  fail "PROXY should reach spotdl's lookups from an empty environment: $(<"$root/recording.env")"

HTTPS_PROXY=http://kept:3128 run mp4 URL >/dev/null
[[ $(<"$root/recording.env") == 'http://kept:3128' ]] ||
  fail 'the other backends take PROXY as an option and leave the environment alone'

# --- a Spotify word inside an option value is not a Spotify URL ----------

run mp3 --output saved 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'yt-dlp '* ]] ||
  fail "'saved' as an option's value must not re-route the run: $(recorded)"

run mp3 saved >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail 'a positional saved still means liked songs'

# --- the --opt=value spelling is translated too --------------------------

run file --cookies="$root/jar" URL >/dev/null
[[ $(recorded) == *'--load-cookies '*'/jar'* ]] ||
  fail "aria2c needs --cookies=FILE translated as well: $(recorded)"
[[ $(recorded) != *'--cookies='* ]] || fail 'the untranslated spelling leaked through'

output=$(run mp3 --cookies-from-browser=firefox 'spotify:track:a' 2>&1 || true)
[[ $output == *'cookie'* ]] ||
  fail "the equals spelling should hit the same guard: $output"

run mp4 --cookies="$root/jar" URL >/dev/null
[[ $(recorded) == *'--cookies='*'/jar'* ]] ||
  fail 'yt-dlp understands the equals spelling and should keep it'

# --- the converter leaves multi-frame images alone -----------------------

command -v magick >/dev/null ||
  fail 'this test needs magick from the imagemagick package'

# Run the real snippet the way gallery-dl does: {} replaced by a quoted path,
# through sh. This is the only part of download that touches a file.
frames=$root/frames
mkdir -p "$frames"
magick -delay 20 -size 20x20 xc:red xc:green xc:blue "$frames/anim.webp"
magick -size 20x20 xc:navy "$frames/still.webp"

exec_snippet=$(: >"$root/recording"; run jpg URL >/dev/null; \
  awk '/^--exec$/ { p = 1; next } p { print }' "$root/recording" | head -n -1)

run_snippet() {
  ( cd "$frames" && printf '%s' "${exec_snippet//\{\}/\'$1\'}" | sh )
}

run_snippet anim.webp || true
[[ -f $frames/anim.webp ]] || fail 'an animated source must survive'
compgen -G "$frames/anim-*.jpg" >/dev/null &&
  fail 'an animated source exploded into numbered frames'
[[ ! -e $frames/anim.jpg ]] || fail 'an animated source should not be converted at all'

run_snippet still.webp || fail 'a still webp should convert'
[[ -f $frames/still.jpg ]] || fail 'a still webp should become a jpg'
[[ ! -e $frames/still.webp ]] || fail 'a converted still should have its original removed'

magick -size 20x20 xc:navy "$frames/collision.webp"
magick -size 20x20 xc:red "$frames/collision.jpg"
collision_hash=$(sha256sum "$frames/collision.jpg")
run_snippet collision.webp 2>/dev/null && fail 'an existing conversion target should be refused'
[[ -f $frames/collision.webp ]] || fail 'a collision must keep the downloaded source'
[[ $(sha256sum "$frames/collision.jpg") == "$collision_hash" ]] ||
  fail 'a collision must not overwrite the existing target'

printf 'not an image' >"$frames/broken.webp"
run_snippet broken.webp 2>/dev/null && fail 'a failed conversion should report failure'
[[ -f $frames/broken.webp ]] || fail 'a failed conversion must keep its source'
[[ ! -e $frames/broken.jpg ]] || fail 'a failed conversion must not publish a target'
compgen -G "$frames/*.tmp.*" >/dev/null &&
  fail 'conversion temporary files must be cleaned up'

# --- yt-dlp comes from bootstrap, not Nix --------------------------------

# A desktop launcher's environment has no ~/.local/bin, so the dispatcher has
# to find the bootstrap binary by the path that phase owns.
mkdir -p "$root/home/.local/bin" "$root/nodl"
cp "$root/bin/yt-dlp" "$root/home/.local/bin/yt-dlp"
for backend in gallery-dl aria2c spotdl; do
  cp "$root/bin/$backend" "$root/nodl/$backend"
done
# A PATH with no yt-dlp on it at all. /usr/bin carries a distro copy, so it
# cannot be here or the fallback is never exercised.
ln -s "$(command -v bash)" "$root/nodl/bash"

without_yt_dlp() {
  : >"$root/recording"
  env -i RECORDING="$root/recording" PATH="$root/nodl" HOME="$1" \
    PROXY=http://p:3128 "$root/nodl/bash" "$repo/scripts/bin/download.sh" mp3 URL
}

without_yt_dlp "$root/home" >/dev/null
[[ $(recorded) == 'yt-dlp '* ]] ||
  fail "should fall back to the bootstrap yt-dlp: $(recorded)"

output=$(without_yt_dlp "$root/empty" 2>&1 || true)
[[ $output == *'bootstrap'* ]] ||
  fail "a missing yt-dlp should name how to install it: $output"

# --- usage ---------------------------------------------------------------

run >/dev/null 2>&1 && fail 'no arguments should be a usage error'
[[ $(run --help) == *'convert-to'* ]] ||
  fail 'help should point at the other command'
[[ $(run --help) == *'PROXY='* ]] || fail 'help should document the proxy bypass'

output=$(run mp3 2>&1 || true)
[[ $output == *'URL'* ]] || fail "a type with no URL should ask for one: $output"

printf 'download tests passed\n'
