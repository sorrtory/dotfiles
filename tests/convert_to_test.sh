#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p "$root/bin" "$root/probe" "$root/work"

# The probe answers from a canned file per input, in the exact shape real
# ffprobe produces: codec_name,codec_type,attached_pic per stream. Verified
# against generated media rather than assumed.
# A duration query gets DURATION, as real ffprobe prints format=duration.
cat >"$root/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
if [[ $* == *format=duration* ]]; then
  printf '%s\n' "${DURATION-200.000000}"
  exit
fi
for argument in "$@"; do :; done
cat "$PROBE_DIR/${argument##*/}" 2>/dev/null
EOF

# ffmpeg records every invocation and creates whatever output path it was
# given last, so a two-pass recipe behaves like the real thing. A requested
# failure writes a partial output first: real ffmpeg can fail after opening and
# truncating its destination, which is the case transactional output protects.
# FFMPEG_EMPTY names an output written empty despite a zero exit.
cat >"$root/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RECORDING"
output=${*: -1}
if [[ ${FFMPEG_FAILS:-} == "${output##*/}" ]]; then
  printf 'partial output\n' >"$output"
  exit 1
fi
if [[ ${FFMPEG_EMPTY:-} == "${output##*/}" ]]; then
  : >"$output"
  exit 0
fi
printf 'converted\n' >"$output"
exit 0
EOF
# magick answers identify from a canned frame count per input, and otherwise
# records itself and writes its last argument like the ffmpeg stand-in.
cat >"$root/bin/magick" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == identify ]]; then
  for argument in "$@"; do :; done
  cat "$FRAMES_DIR/${argument##*/}" 2>/dev/null
  exit
fi
printf 'magick %s\n' "$*" >>"$RECORDING"
output=${*: -1}
printf 'converted\n' >"${output//%%/%}"
EOF
chmod +x "$root/bin/ffprobe" "$root/bin/ffmpeg" "$root/bin/magick"

mkdir -p "$root/frames"
printf '1\n' >"$root/frames/still.png"
printf '1\n' >"$root/frames/photo.webp"
printf '1\n' >"$root/frames/shot.jpg"
printf '12\n12\n' >"$root/frames/moving.webp"

printf 'h264,video,0\naac,audio,0\n' >"$root/probe/compatible.mkv"
printf 'vp9,video,0\nopus,audio,0\n' >"$root/probe/vp9.webm"
printf 'h264,video,0\naac,audio,0\n' >"$root/probe/already.mp4"
printf 'mp3,audio,0\nmjpeg,video,1\n' >"$root/probe/withcover.mp3"
printf 'mp3,audio,0\n'               >"$root/probe/bare.mp3"

reset_inputs() {
  rm -rf -- "$root/work"
  mkdir -p "$root/work"
  for name in compatible.mkv vp9.webm already.mp4 withcover.mp3 bare.mp3 \
    still.png photo.webp shot.jpg moving.webp; do
    printf 'input\n' >"$root/work/$name"
  done
}

run() {
  : >"$root/recording"
  (
    cd "$root/work" &&
      RECORDING=$root/recording PROBE_DIR=$root/probe FRAMES_DIR=$root/frames \
        PATH="$root/bin:$PATH" \
        bash "$repo/scripts/bin/convert-to.sh" "$@"
  )
}

calls() { cat "$root/recording"; }

# --- the four mp4 recipes -------------------------------------------------

reset_inputs
run mp4 compatible.mkv >/dev/null
[[ $(calls) == *'-c copy'* ]] ||
  fail "h264+aac in another container should remux: $(calls)"
[[ $(calls) != *'libx264'* ]] || fail 'a remux must not re-encode'

reset_inputs
run mp4 vp9.webm >/dev/null
[[ $(calls) == *'libx264'* ]] || fail "vp9 cannot be remuxed into mp4: $(calls)"
[[ $(calls) != *'-c copy'* ]] || fail 'a transcode must not claim to copy'

reset_inputs
run mp4 withcover.mp3 >/dev/null
[[ $(calls) == *'-loop 1'* ]] ||
  fail "audio with cover art should become a still video: $(calls)"
[[ $(calls) == *'attached_pic'* || $(calls) == *'-frames:v 1'* ]] ||
  fail 'the cover has to be extracted before it can be looped'

reset_inputs
output=$(run mp4 bare.mp3 2>&1 || true)
[[ $output == *'cover'* ]] ||
  fail "audio with no cover art should say so rather than make a black video: $output"
[[ ! -s $root/recording ]] || fail 'a refused input must not reach ffmpeg'

# --- mp3 and gif ----------------------------------------------------------

reset_inputs
run mp3 compatible.mkv >/dev/null
[[ $(calls) == *'libmp3lame'* ]] || fail "mp3 should encode with lame: $(calls)"
[[ $(calls) == *'-vn'* ]] || fail "a clip's video is not cover art: $(calls)"

reset_inputs
run mp3 withcover.mp3 >/dev/null
[[ $(calls) == *'-map 0:v:0 -c:v copy -disposition:v attached_pic'* ]] ||
  fail "cover art should survive into the mp3: $(calls)"

# The cover is found by its place among the video streams, not assumed first.
reset_inputs
cp "$root/work/bare.mp3" "$root/work/album.mka"
printf 'flac,audio,0\nh264,video,0\nmjpeg,video,1\n' >"$root/probe/album.mka"
run mp3 album.mka >/dev/null
[[ $(calls) == *'-map 0:v:1 '* ]] || fail "the cover is the second video stream: $(calls)"

reset_inputs
run gif compatible.mkv >/dev/null
[[ $(calls) == *'palettegen'* ]] || fail 'a good gif needs a generated palette'
[[ $(calls) == *'paletteuse'* ]] || fail 'the second pass has to use that palette'
[[ $(calls) == *'fps=15'* ]] || fail "gif should default to a sendable frame rate: $(calls)"
[[ $(calls) == *'480'* ]] || fail 'gif should default to a sendable width'
[[ $(wc -l <"$root/recording") -eq 2 ]] ||
  fail "a two-pass gif is exactly two ffmpeg runs: $(calls)"

reset_inputs
output=$(run gif bare.mp3 2>&1 || true)
[[ $output == *'video'* ]] || fail "a gif needs a video stream: $output"

# --- nothing is ever removed ---------------------------------------------

reset_inputs
run mp4 vp9.webm >/dev/null
[[ -f $root/work/vp9.webm ]] || fail 'convert-to must never remove an original'

# --- the output already exists -------------------------------------------

reset_inputs
printf 'precious\n' >"$root/work/compatible.mp4"
output=$(run mp4 compatible.mkv 2>&1 || true)
[[ $output == *'compatible.mp4'* ]] || fail "a collision should name the file: $output"
[[ $(<"$root/work/compatible.mp4") == 'precious' ]] ||
  fail 'an existing output must survive untouched'
[[ ! -s $root/recording ]] || fail 'nothing should be encoded when a target exists'

# The whole batch is refused, so a later good file is not converted either.
reset_inputs
printf 'precious\n' >"$root/work/compatible.mp4"
output=$(run mp4 compatible.mkv vp9.webm 2>&1 || true)
[[ ! -s $root/recording ]] ||
  fail "one collision should refuse the batch before any encoding: $(calls)"
[[ ! -e $root/work/vp9.mp4 ]] || fail 'the clean file was converted despite the refusal'

reset_inputs
printf 'precious\n' >"$root/work/compatible.mp4"
run --force mp4 compatible.mkv >/dev/null
[[ -s $root/recording ]] || fail '--force should proceed anyway'

# Converting a file into its own name is the one case that is not a refusal.
reset_inputs
run mp4 already.mp4 >/dev/null
[[ $(calls) == *'already.converted.mp4'* ]] ||
  fail "a file cannot be converted onto itself: $(calls)"

# --- a batch keeps going, and says so ------------------------------------

reset_inputs
if FFMPEG_FAILS=vp9.mp4 run mp4 vp9.webm compatible.mkv >"$root/out" 2>&1; then
  fail 'a failed encode should make the run exit non-zero'
fi
[[ $(calls) == *'compatible.mp4'* ]] ||
  fail 'the rest of the batch should run after one failure'
[[ $(<"$root/out") == *'vp9.webm'* ]] || fail 'the summary should name what failed'

# --- --force must not cost you the file it overwrites --------------------

# The whole point of --force is that the output already exists. If the encode
# then fails, cleaning up "our" half-written file would delete the operator's.
reset_inputs
printf 'PRECIOUS\n' >"$root/work/vp9.mp4"
if FFMPEG_FAILS=vp9.mp4 run --force mp4 vp9.webm >/dev/null 2>&1; then
  fail 'a failed encode should still exit non-zero under --force'
fi
[[ -f $root/work/vp9.mp4 ]] ||
  fail 'a failed --force encode deleted the file it was overwriting'
[[ $(<"$root/work/vp9.mp4") == 'PRECIOUS' ]] ||
  fail 'the pre-existing output should be left as it was'
[[ -z $(find "$root/work" -maxdepth 1 -type d -name '.convert-to.*' -print -quit) ]] ||
  fail 'a failed conversion left its temporary output behind'

# Without --force the output cannot pre-exist, so a failure does clean up.
reset_inputs
if FFMPEG_FAILS=vp9.mp4 run mp4 vp9.webm >/dev/null 2>&1; then
  fail 'a failed encode should exit non-zero'
fi
[[ ! -e $root/work/vp9.mp4 ]] ||
  fail 'a half-written file this run created should be cleaned up'

# --- two inputs cannot claim one output ----------------------------------

reset_inputs
cp "$root/work/bare.mp3" "$root/work/clash.wav"
cp "$root/work/bare.mp3" "$root/work/clash.flac"
printf 'mp3,audio,0\n' >"$root/probe/clash.wav"
printf 'mp3,audio,0\n' >"$root/probe/clash.flac"
output=$(run mp3 clash.wav clash.flac 2>&1 || true)
[[ $output == *'clash.mp3'* ]] ||
  fail "a batch that overwrites itself should name the output: $output"
[[ ! -s $root/recording ]] ||
  fail 'a self-colliding batch must be refused before encoding'

# --force is about files that were already there, not about losing a result.
output=$(run --force mp3 clash.wav clash.flac 2>&1 || true)
[[ ! -s $root/recording ]] || fail '--force must not permit a batch to eat itself'

# --- a typo is not an ffmpeg output --------------------------------------

# ffmpeg reads a bare token before the output as another output, so passing a
# misspelt input through would quietly write a file at the typo'd path.
reset_inputs
output=$(run mp3 compatible.mkv sogn.mp3 2>&1 || true)
[[ $output == *'sogn.mp3'* ]] || fail "a missing input should be named: $output"
[[ ! -e $root/work/sogn.mp3 ]] || fail 'a typo became a file'
[[ ! -s $root/recording ]] || fail 'nothing should run when an input is missing'

# An option's value is not a filename, and must still pass through.
reset_inputs
run mp3 -q:a 2 compatible.mkv >/dev/null
[[ $(calls) == *'-q:a 2'* ]] || fail "an option's value should reach ffmpeg: $(calls)"

# --- the output stays beside its input -----------------------------------

# ${input%.*} cuts at the last dot anywhere in the path, so an extensionless
# file in a dotted directory used to land outside that directory.
reset_inputs
mkdir -p "$root/work/dot.dir"
cp "$root/work/compatible.mkv" "$root/work/dot.dir/clip"
printf 'h264,video,0\naac,audio,0\n' >"$root/probe/clip"
run mp4 dot.dir/clip >/dev/null
[[ -e $root/work/dot.dir/clip.mp4 ]] ||
  fail 'the output was not installed beside its input'
[[ ! -e $root/work/dot.mp4 ]] || fail 'the output escaped its directory'

# --- remux keeps what transcode keeps ------------------------------------

reset_inputs
run mp4 compatible.mkv >/dev/null
[[ $(calls) == *'-map 0:v:0'* && $(calls) == *"-map 0:a?"* ]] ||
  fail "a remux should select streams like the transcode does: $(calls)"

# --- --cover -------------------------------------------------------------

add_pictures() {
  printf 'mjpeg,video,0\n' >"$root/probe/art.jpg"
  printf 'webp,video,0\n' >"$root/probe/art.webp"
  printf 'gif,video,0\n' >"$root/probe/moving.gif"
  printf '1\n' >"$root/frames/art.jpg"
  printf '1\n' >"$root/frames/art.webp"
  printf '5\n5\n' >"$root/frames/moving.gif"
  for name in art.jpg art.webp moving.gif; do
    printf 'picture\n' >"$root/work/$name"
  done
}

# Adding a picture to an mp3 must not re-encode its audio.
reset_inputs
add_pictures
run mp3 bare.mp3 --cover art.jpg >/dev/null
[[ $(calls) == *'-i ./art.jpg'* && $(calls) == *'-map 1:v:0'* ]] ||
  fail "--cover should embed the given picture: $(calls)"
[[ $(calls) == *'-c:a copy'* && $(calls) != *'libmp3lame'* ]] ||
  fail "an mp3 given a cover should keep its audio untouched: $(calls)"
[[ $(calls) == *'-c:v copy'* ]] || fail "a jpeg cover needs no re-encode: $(calls)"
[[ $(calls) == *'Cover (front)'* ]] || fail "the picture should be the front cover: $(calls)"
[[ $(calls) != *'-frames:v'* ]] ||
  fail "-frames:v ends the whole output, audio too, after one frame: $(calls)"
[[ -e $root/work/bare.converted.mp3 ]] || fail 'the mp3 was not written beside itself'

# The picture replaces the source's own art rather than joining it.
reset_inputs
add_pictures
run mp3 withcover.mp3 --cover=art.webp >/dev/null
[[ $(calls) != *'-map 0:v'* ]] || fail "--cover should replace existing art: $(calls)"
[[ $(calls) == *'-c:v mjpeg'* ]] || fail "a webp cover should become jpeg: $(calls)"

reset_inputs
add_pictures
run mp3 compatible.mkv --cover art.jpg >/dev/null
[[ $(calls) == *'libmp3lame'* ]] || fail "other audio is still encoded to mp3: $(calls)"

# Audio with no art of its own was a dead end for mp4 until a picture is given.
reset_inputs
add_pictures
run mp4 bare.mp3 --cover art.jpg >/dev/null
[[ $(calls) == *'-i ./art.jpg'* && $(calls) == *'-loop 1'* ]] ||
  fail "--cover should make the still video: $(calls)"

reset_inputs
add_pictures
output=$(run mp4 vp9.webm --cover art.jpg 2>&1 || true)
[[ $output == *'already a video'* ]] || fail "a video cannot take a cover: $output"
[[ ! -s $root/recording ]] || fail 'a refused cover must not reach ffmpeg'

reset_inputs
add_pictures
output=$(run gif compatible.mkv --cover art.jpg 2>&1 || true)
[[ $output == *'--cover'* ]] || fail "--cover means nothing to gif: $output"

for bad in missing.jpg moving.gif; do
  reset_inputs
  add_pictures
  output=$(run mp3 bare.mp3 --cover "$bad" 2>&1 || true)
  [[ $output == *"$bad"* ]] || fail "a bad cover should be named: $output"
  [[ ! -s $root/recording ]] || fail "nothing should run with cover $bad"
done

reset_inputs
output=$(run mp3 bare.mp3 --cover 2>&1 || true)
[[ $output == *'needs a picture'* ]] || fail "--cover without a value: $output"

# --- mp3 to mp4: length and thumbnail ------------------------------------

# -shortest overshot a 60 second song to 117 seconds of video; the still is cut
# at the audio's measured length instead.
reset_inputs
DURATION=187.5 run mp4 withcover.mp3 >/dev/null
[[ $(calls) == *'-t 187.5'* ]] || fail "the still should end with the audio: $(calls)"
[[ $(calls) != *'-shortest'* ]] || fail "-shortest overshoots once a length is known: $(calls)"

reset_inputs
DURATION=N/A run mp4 withcover.mp3 >/dev/null
[[ $(calls) == *'-shortest'* ]] || fail "an unknown length falls back to -shortest: $(calls)"

# The picture is also the mp4's own cover, so thumbnailers need not guess.
reset_inputs
run mp4 withcover.mp3 >/dev/null
[[ $(calls) == *'-disposition:v:1 attached_pic'* ]] ||
  fail "the mp4 should carry the picture as its cover: $(calls)"
[[ -e $root/work/withcover.mp4 ]] || fail 'the still video was not installed'
[[ -z $(find "$root/work" -name 'still.mp4' -print -quit) ]] ||
  fail 'the intermediate still video was left behind'

# --- -R, --replace -------------------------------------------------------

# Rewriting an mp3 in place is what -R is for.
reset_inputs
add_pictures
chmod 640 "$root/work/bare.mp3"
run mp3 -R bare.mp3 --cover art.jpg >/dev/null
[[ $(<"$root/work/bare.mp3") == 'converted' ]] || fail '-R should rewrite the mp3 in place'
[[ ! -e $root/work/bare.converted.mp3 ]] || fail '-R should not write a .converted copy'
[[ $(stat -c %a "$root/work/bare.mp3") == 640 ]] || fail '-R should keep the file mode'
[[ -z $(find "$root/work" -maxdepth 1 -name '.convert-to.*' -print -quit) ]] ||
  fail '-R left its temporary directory behind'

# Across formats the original goes, but only once its replacement exists.
reset_inputs
run --replace mp4 vp9.webm >/dev/null
[[ -e $root/work/vp9.mp4 ]] || fail '--replace should still write the output'
[[ ! -e $root/work/vp9.webm ]] || fail '--replace should remove the original'

for failure in FFMPEG_FAILS FFMPEG_EMPTY; do
  reset_inputs
  export "$failure=vp9.mp4"
  if run -R mp4 vp9.webm >/dev/null 2>&1; then
    fail "-R with $failure should exit non-zero"
  fi
  unset "$failure"
  [[ $(<"$root/work/vp9.webm") == 'input' ]] || fail "-R lost the original after $failure"
  [[ ! -e $root/work/vp9.mp4 ]] || fail "-R installed a bad output after $failure"
done

# -R replaces its own input, not some other file that happens to be there.
reset_inputs
printf 'precious\n' >"$root/work/vp9.mp4"
output=$(run -R mp4 vp9.webm 2>&1 || true)
[[ $output == *'vp9.mp4 already exists'* ]] || fail "-R must still respect collisions: $output"
[[ -e $root/work/vp9.webm && $(<"$root/work/vp9.mp4") == 'precious' ]] ||
  fail '-R touched files after a refused batch'

# -R is ours: ffmpeg has no -R, and passing it on would fail every encode.
reset_inputs
run -R mp3 compatible.mkv >/dev/null
[[ $(calls) != *' -R'* ]] || fail "-R must not reach ffmpeg: $(calls)"

# --- still images --------------------------------------------------------

reset_inputs
run jpg still.png photo.webp >/dev/null
[[ -e $root/work/still.jpg && -e $root/work/photo.jpg ]] ||
  fail "png and webp should both become jpg: $(calls)"
[[ $(calls) == *'-alpha remove'* ]] ||
  fail "jpg has no alpha, so transparency must be flattened: $(calls)"
[[ -f $root/work/still.png ]] || fail 'an image conversion removed its original'

reset_inputs
run png shot.jpg >/dev/null
[[ -e $root/work/shot.png ]] || fail "an explicit jpeg to png should convert: $(calls)"

reset_inputs
run jpg shot.jpg >/dev/null
[[ -e $root/work/shot.converted.jpg ]] ||
  fail "a jpg converted to jpg should not land on itself: $(calls)"

# ImageMagick writes name-0, name-1 and so on for an animation.
reset_inputs
output=$(run jpg moving.webp 2>&1 || true)
[[ $output == *'frames'* ]] || fail "an animation should be refused by name: $output"
[[ ! -s $root/recording ]] || fail 'an animation must not reach the converter'

reset_inputs
printf 'precious\n' >"$root/work/still.jpg"
run jpg still.png >/dev/null 2>&1 || true
[[ $(<"$root/work/still.jpg") == 'precious' ]] ||
  fail 'an image conversion must honour the collision check'

# ImageMagick expands %d in an output name, so it has to be escaped.
reset_inputs
cp "$root/work/still.png" "$root/work/100%d.png"
printf '1\n' >"$root/frames/100%d.png"
run jpg '100%d.png' >/dev/null
[[ $(calls) == *'100%%d.jpg'* ]] || fail "a percent sign in a name was not escaped: $(calls)"
[[ -e $root/work/100%d.jpg ]] || fail 'the percent-named file did not convert'

# --- a colon is not a protocol -------------------------------------------

# ffmpeg reads 'Song: Live.mkv' as a URL whose protocol is 'Song'.
reset_inputs
cp "$root/work/compatible.mkv" "$root/work/Song: Live.mkv"
printf 'h264,video,0\naac,audio,0\n' >"$root/probe/Song: Live.mkv"
run mp4 'Song: Live.mkv' >/dev/null
[[ $(calls) == *'-i ./Song: Live.mkv'* ]] ||
  fail "a relative path should reach ffmpeg as ./path: $(calls)"
[[ -e "$root/work/Song: Live.mp4" ]] || fail 'the colon-named file did not convert'

# --- usage ---------------------------------------------------------------

run >/dev/null 2>&1 && fail 'no arguments should be a usage error'
[[ $(run --help) == *'download'* ]] || fail 'help should point at the other command'

output=$(run webm compatible.mkv 2>&1 || true)
[[ $output == *'webm'* ]] || fail "an unsupported target should name it: $output"

printf 'convert-to tests passed\n'
