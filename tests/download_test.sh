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
for backend in yt-dlp gallery-dl aria2c spotdl gdown; do
  cat >"$root/bin/$backend" <<EOF
#!/usr/bin/env bash
{ printf '$backend\n'; printf '%s\n' "\$@"; } >"\$RECORDING"
printf '%s\n' "\${HTTPS_PROXY-unset}" >"\$RECORDING.env"
EOF
  chmod +x "$root/bin/$backend"
done

cat >"$root/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$RECORDING.curl"
printf '%s\n' "${HTTPS_PROXY-unset}" >"$RECORDING.curl-env"
[[ ${YANDEX_CURL_FAIL:-0} == 0 ]] || exit 22
printf '%s\n' "${YANDEX_RESPONSE:-{\"href\":\"https://download.example/file?token=abc\"}}"
EOF
chmod +x "$root/bin/curl"

# Runs the subject with the mocks first on PATH and the recording emptied.
# PROXY is set unless the caller overrides it, because the interesting default
# is "a proxy is configured".
run() {
  : >"$root/recording"
  RECORDING=$root/recording PATH="$root/bin:$PATH" PROXY=${PROXY-http://p:3128} \
    bash "$repo/scripts/bin/download.sh" "$@"
}

recorded() { tr '\n' ' ' <"$root/recording"; }

# --- output request and explicit downloader ------------------------------

run --as audio --using yt-dlp URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 -x URL '* ]] ||
  fail "bare audio should extract without a format: $(recorded)"

run --as mp3 --using yt-dlp URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 -x --audio-format mp3 URL '* ]] ||
  fail "mp3 should name the audio format: $(recorded)"

run --as video --using yt-dlp URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 URL '* ]] ||
  fail "bare video should neither extract nor recode: $(recorded)"

run --as mp4 --using yt-dlp URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 --recode-video mp4 URL '* ]] ||
  fail "mp4 should recode, never remux: $(recorded)"
[[ $(recorded) != *'--remux-video'* ]] ||
  fail 'remuxing fails outright when the codecs do not fit the container'

run --as original --using gallery-dl URL >/dev/null
[[ $(recorded) == 'gallery-dl --proxy http://p:3128 URL '* ]] ||
  fail "bare image should publish as downloaded: $(recorded)"
[[ $(recorded) != *'--exec'* ]] ||
  fail 'bare image must not run a converter'

run --as jpg --using gallery-dl URL >/dev/null
[[ $(recorded) == 'gallery-dl --proxy http://p:3128 --exec '* ]] ||
  fail "jpg should convert through gallery-dl's exec: $(recorded)"

run --as file --using aria2c URL >/dev/null
[[ $(recorded) == 'aria2c --all-proxy http://p:3128 -x8 -s8 --continue --force-sequential=true URL '* ]] ||
  fail "file should reach aria2c with real parallelism: $(recorded)"

run --as file --using aria2c URL1 URL2 >/dev/null
[[ $(recorded) == *'--force-sequential=true URL1 URL2 '* ]] ||
  fail "multiple file URLs must be separate downloads, not mirrors: $(recorded)"

# --- URL-only defaults ---------------------------------------------------

run 'https://youtu.be/abc' >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 https://youtu.be/abc '* ]] ||
  fail "YouTube should keep video via yt-dlp: $(recorded)"

for site in 'https://vimeo.com/123' 'https://www.tiktok.com/@u/video/123' \
  'https://www.twitch.tv/videos/123'; do
  run "$site" >/dev/null
  [[ $(recorded) == yt-dlp\ * ]] || fail "$site should use yt-dlp"
done

run 'https://soundcloud.com/artist/track' >/dev/null
[[ $(recorded) == 'yt-dlp --proxy http://p:3128 -x https://soundcloud.com/artist/track '* ]] ||
  fail "SoundCloud should extract audio via yt-dlp: $(recorded)"

run 'https://open.spotify.com/track/abc' >/dev/null
[[ $(recorded) == *'spotdl '*'--format mp3'* ]] ||
  fail "Spotify should use spotdl with mp3 output: $(recorded)"

for site in 'https://www.pinterest.com/pin/123' 'https://pin.it/abc' \
  'https://www.instagram.com/p/abc' 'https://imgur.com/a/abc' \
  'https://www.pixiv.net/artworks/123' 'https://www.artstation.com/artwork/abc' \
  'https://www.deviantart.com/u/art/x' 'https://www.flickr.com/photos/u/123'; do
  run "$site" >/dev/null
  [[ $(recorded) == gallery-dl\ * ]] ||
    fail "$site should use gallery-dl: $(recorded)"
done

run --as jpg 'https://www.pinterest.com/pin/123' >/dev/null
[[ $(recorded) == *'--exec'* ]] || fail 'Pinterest JPG should use the image converter'

run --using gallery-dl 'https://youtu.be/abc' >/dev/null
[[ $(recorded) == 'gallery-dl '* ]] ||
  fail 'an explicit downloader should override the URL default'

run 'https://example.org/archive.zip?token=abc' >/dev/null
[[ $(recorded) == 'aria2c '* ]] || fail 'a direct file URL should use aria2c'

run 'https://disk.yandex.ru/d/abc' >/dev/null
[[ $(recorded) == *'https://download.example/file?token=abc '* ]] ||
  fail 'a Yandex share link should resolve without --as or --using'

run 'https://drive.google.com/file/d/abc/view' >/dev/null
[[ $(recorded) == 'gdown --proxy http://p:3128 https://drive.google.com/file/d/abc/view '* ]] ||
  fail "Google Drive should use gdown with PROXY: $(recorded)"

run --cookies-from-browser firefox 'https://docs.google.com/document/d/abc/edit' >/dev/null
[[ $(recorded) == *'--cookies-from-browser firefox '* ]] ||
  fail 'gdown should receive browser cookies when requested'

PROXY= HTTPS_PROXY=http://leak:3128 run 'https://drive.google.com/file/d/abc/view' >/dev/null
[[ $(<"$root/recording.env") == unset ]] || fail 'direct gdown should clear ambient proxy variables'

output=$(run 'https://example.org/page' 2>&1) && fail 'an unknown site without a terminal should stop'
[[ $output == *'use --using'* ]] || fail "unknown-site help should name the override: $output"
[[ ! -s $root/recording ]] || fail 'an unknown site must not start a downloader'

output=$(run 'https://youtube.com.evil.example/watch' 2>&1) && fail 'a spoofed host should not match YouTube'
[[ $output == *'use --using'* ]] || fail 'host matching must respect hostname boundaries'

output=$(run 'https://youtu.be/a' 'https://pin.it/b' 2>&1) && fail 'mixed backends need separate invocations'
[[ $output == *'different downloaders'* ]] || fail "mixed URL diagnostic: $output"

output=$(run --as= 'https://youtu.be/a' 2>&1) && fail 'empty --as should be rejected'
[[ $output == *'--as needs a value'* ]] || fail "empty --as diagnostic: $output"

output=$(run --as mp3 'https://pin.it/b' 2>&1) && fail 'unsupported output must stop before downloading'
[[ $output == *'gallery-dl cannot produce'* ]] || fail "unsupported output diagnostic: $output"
[[ ! -s $root/recording ]] || fail 'unsupported output must not reach a backend'

# --- Yandex.Disk public links --------------------------------------------

yandex_url='https://disk.yandex.ru/d/abc?foo=one&bar=two'
run --as file --using aria2c "$yandex_url" 'https://example.org/other' -- -d "$root/out" >/dev/null
[[ $(recorded) == *'--content-disposition=true -d '* ]] ||
  fail "Yandex downloads should retain the server's filename: $(recorded)"
[[ $(recorded) == *'https://download.example/file?token=abc https://example.org/other '* ]] ||
  fail "only the Yandex link should be replaced, in order: $(recorded)"
grep -Fxq -- "public_key=$yandex_url" "$root/recording.curl" ||
  fail 'the entire share link must be URL-encoded as public_key'
grep -Fxq -- '--data-urlencode' "$root/recording.curl" ||
  fail 'the public key must use curl URL encoding'
grep -Fxq -- 'http://p:3128' "$root/recording.curl" ||
  fail 'the API request must use PROXY'

PROXY= HTTPS_PROXY=http://leak:3128 run --as file --using aria2c 'https://yadi.sk/i/abc' >/dev/null
[[ $(<"$root/recording.curl-env") == unset ]] ||
  fail 'a direct API lookup must not inherit HTTPS_PROXY'
grep -Fxq -- '--proxy' "$root/recording.curl" || fail 'curl needs an explicit proxy setting'
grep -Fxq -- '' "$root/recording.curl" || fail 'curl needs an empty proxy for direct mode'

rm -f "$root/recording.curl"
run --as file --using aria2c 'https://example.org/file' >/dev/null
[[ ! -e $root/recording.curl ]] || fail 'ordinary URLs must not call the Disk API'

run --as original --using gallery-dl "$yandex_url" >/dev/null
[[ $(recorded) == *"$yandex_url "* ]] ||
  fail 'Yandex resolution belongs only to the file backend'

output=$(YANDEX_RESPONSE='{"error":"DiskNotFoundError"}' run --as file --using aria2c "$yandex_url" 2>&1) &&
  fail 'an API response without href must fail before downloading'
[[ $output == *'did not return a download URL'* ]] || fail "missing href error: $output"
[[ ! -s $root/recording ]] || fail 'a failed lookup must not reach aria2c'

output=$(YANDEX_CURL_FAIL=1 run --as file --using aria2c "$yandex_url" 2>&1) &&
  fail 'a failed API request must stop the download'
[[ $output == *'could not resolve Yandex.Disk link'* ]] || fail "API failure: $output"
[[ ! -s $root/recording ]] || fail 'a failed API request must not reach aria2c'

# --- the conversion snippets --------------------------------------------

run --as jpg --using gallery-dl URL >/dev/null
grep -q 'png|webp|bmp|tif|tiff|avif|jxl|heic|heif' "$root/recording" ||
  fail 'jpg should convert every still format it can'
grep -q 'jpg' "$root/recording" || fail 'jpg snippet should target jpg'

run --as png --using gallery-dl URL >/dev/null
grep -q 'webp|avif|jxl|heic|heif' "$root/recording" ||
  fail 'png should normalise the lossless-ish formats'
grep -qE '\bpng\|' "$root/recording" &&
  fail 'png must not re-encode JPEG or PNG sources into PNG'
grep -q 'jpe\?g' "$root/recording" &&
  fail 'png must leave JPEG alone rather than inflating it'

# --- format vocabulary ---------------------------------------------------

run --as ogg --using yt-dlp URL >/dev/null
[[ $(recorded) == *'--audio-format vorbis'* ]] ||
  fail "yt-dlp spells ogg 'vorbis': $(recorded)"

run --as gif URL 2>/dev/null && fail 'gif is a convert-to target, not a download one'
[[ ! -s $root/recording ]] || fail 'a rejected type must not reach a backend'

output=$(run --as gif URL 2>&1 || true)
[[ $output == *'convert-to'* ]] || fail "gif should point at convert-to: $output"

output=$(run --as mpeg URL 2>&1 || true)
[[ $output == *'mpeg'* ]] || fail "an unknown type should name what was given: $output"

# --- Spotify routing -----------------------------------------------------

run --as mp3 'https://open.spotify.com/track/abc' >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail "a Spotify URL has no other backend: $(recorded)"
[[ $(recorded) == *'--format mp3'* ]] || fail "spotdl spells it --format: $(recorded)"

run --as mp3 'spotify:track:abc' >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail 'a spotify: URI should route to spotdl'

run --as mp3 saved >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail "'saved' means liked songs, which only spotdl reads"

run --as mp3 saved -- --user-auth >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail "a valueless option before 'saved' must not hide the spotdl query"

output=$(run --as audio 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'supports --as mp3'* ]] ||
  fail "Spotify audio should require an encoded output format: $output"
[[ ! -s $root/recording ]] || fail 'formatless Spotify audio must not reach spotdl'

run --as mp3 --using yt-dlp 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'yt-dlp '* ]] ||
  fail "YouTube must not be matched against Spotify by default: $(recorded)"

run --spotify-meta --as mp3 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'spotdl '* ]] ||
  fail '--spotify-meta should opt a YouTube URL into Spotify tagging'
[[ $(recorded) != *'--spotify-meta'* ]] ||
  fail 'the flag is ours and must not leak to the backend'

run --as mp3 --spotify-meta 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail '--spotify-meta should be positional-agnostic'

output=$(run --as aac 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'mp3'* && $output == *'flac'* ]] ||
  fail "an impossible Spotify format should name the possible ones: $output"
[[ ! -s $root/recording ]] || fail 'an impossible format must not reach spotdl'

run --as aac --using yt-dlp 'https://youtube.com/watch?v=x' >/dev/null
[[ $(recorded) == 'yt-dlp '*'--audio-format aac'* ]] ||
  fail 'aac is fine everywhere except Spotify'

output=$(run --as mp4 'https://open.spotify.com/track/abc' 2>&1 || true)
[[ $output == *'spotdl supports --as'* ]] || fail "Spotify has no video: $output"

# --- proxy ---------------------------------------------------------------

PROXY= run --as mp4 --using yt-dlp URL >/dev/null
[[ $(recorded) == 'yt-dlp --proxy  --recode-video mp4 URL '* ]] ||
  fail "an empty PROXY should ask yt-dlp for a direct connection: $(recorded)"
[[ $(recorded) != *'http://p:3128'* ]] ||
  fail 'an empty PROXY must not produce a proxy address'

PROXY= run --as jpg --using gallery-dl URL >/dev/null
[[ $(recorded) == *'proxy-env=false'* ]] ||
  fail "gallery-dl ignores an empty --proxy and falls back to the environment: $(recorded)"

PROXY= run --as file --using aria2c URL >/dev/null
[[ $(recorded) == 'aria2c --all-proxy  '* ]] ||
  fail "aria2c overrides a previous proxy with an empty value: $(recorded)"

# --- passthrough ---------------------------------------------------------

run --as mp4 --using yt-dlp URL -- --playlist-items 1-3 >/dev/null
[[ $(recorded) == *'--playlist-items 1-3 URL '* ]] ||
  fail "backend options should survive in order: $(recorded)"

run --as jpg --using gallery-dl --cookies-from-browser firefox URL -- --range 1-5 >/dev/null
[[ $(recorded) == *'--cookies-from-browser firefox --range 1-5 URL '* ]] ||
  fail 'gallery-dl options should pass through untouched'

run --as file --using aria2c --cookies "$root/jar" URL >/dev/null
[[ $(recorded) == *'--load-cookies '*'/jar'* ]] ||
  fail "aria2c spells a cookie jar --load-cookies: $(recorded)"

run --as mp3 --cookies "$root/jar" 'https://open.spotify.com/track/a' >/dev/null
[[ $(recorded) == *'--cookie-file '*'/jar'* ]] ||
  fail "spotdl spells it --cookie-file: $(recorded)"

output=$(run --as mp3 --cookies-from-browser firefox 'https://open.spotify.com/t/a' 2>&1 || true)
[[ $output == *'--cookies'* ]] ||
  fail "spotdl cannot read a browser's cookies and should say so: $output"

# --- the environment is cleared for a direct run -------------------------

# spotdl has no empty-proxy spelling and reads these itself, as does the yt-dlp
# it drives, so PROXY= has to clear them or proxy-on would still tunnel.
HTTPS_PROXY=http://leak:3128 PROXY= run --as mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'unset' ]] ||
  fail "a direct run must not leave a proxy in spotdl's environment: $(<"$root/recording.env")"

# spotdl's metadata lookups read only the environment, and region blocks make
# them fail direct, so a proxied run puts PROXY there — over whatever the
# caller's environment held, or held nothing at all.
HTTPS_PROXY=http://stale:3128 run --as mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'http://p:3128' ]] ||
  fail "a proxied spotdl run should see PROXY in its environment: $(<"$root/recording.env")"

run --as mp3 'spotify:track:a' >/dev/null
[[ $(<"$root/recording.env") == 'http://p:3128' ]] ||
  fail "PROXY should reach spotdl's lookups from an empty environment: $(<"$root/recording.env")"

HTTPS_PROXY=http://kept:3128 run --as mp4 --using yt-dlp URL >/dev/null
[[ $(<"$root/recording.env") == 'http://kept:3128' ]] ||
  fail 'the other backends take PROXY as an option and leave the environment alone'

# --- a Spotify word inside an option value is not a Spotify URL ----------

run --as mp3 'https://youtube.com/watch?v=x' -- --output saved >/dev/null
[[ $(recorded) == 'yt-dlp '* ]] ||
  fail "'saved' as an option's value must not re-route the run: $(recorded)"

run --as mp3 saved >/dev/null
[[ $(recorded) == 'spotdl '* ]] || fail 'a positional saved still means liked songs'

# --- the --opt=value spelling is translated too --------------------------

run --as file --using aria2c --cookies="$root/jar" URL >/dev/null
[[ $(recorded) == *'--load-cookies '*'/jar'* ]] ||
  fail "aria2c needs --cookies=FILE translated as well: $(recorded)"
[[ $(recorded) != *'--cookies='* ]] || fail 'the untranslated spelling leaked through'

output=$(run --as mp3 --cookies-from-browser=firefox 'spotify:track:a' 2>&1 || true)
[[ $output == *'cookie'* ]] ||
  fail "the equals spelling should hit the same guard: $output"

run --as mp4 --using yt-dlp --cookies="$root/jar" URL >/dev/null
[[ $(recorded) == *'--cookies '*'/jar'* ]] ||
  fail 'the equals spelling should be normalized for yt-dlp'

# --- the converter leaves multi-frame images alone -----------------------

command -v magick >/dev/null ||
  fail 'this test needs magick from the imagemagick package'

# Run the real snippet the way gallery-dl does: {} replaced by a quoted path,
# through sh. This is the only part of download that touches a file.
frames=$root/frames
mkdir -p "$frames"
magick -delay 20 -size 20x20 xc:red xc:green xc:blue "$frames/anim.webp"
magick -size 20x20 xc:navy "$frames/still.webp"

exec_snippet=$(: >"$root/recording"; run --as jpg --using gallery-dl URL >/dev/null; \
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
    PROXY=http://p:3128 "$root/nodl/bash" "$repo/scripts/bin/download.sh" --as mp3 --using yt-dlp URL
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

output=$(run --as mp3 --using yt-dlp 2>&1 || true)
[[ $output == *'URL'* ]] || fail "a type with no URL should ask for one: $output"

printf 'download tests passed\n'
