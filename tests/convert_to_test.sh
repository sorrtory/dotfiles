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
cat >"$root/bin/ffprobe" <<'EOF'
#!/usr/bin/env bash
for argument in "$@"; do :; done
cat "$PROBE_DIR/${argument##*/}" 2>/dev/null
EOF

# ffmpeg records every invocation and creates whatever output path it was
# given last, so a two-pass recipe behaves like the real thing.
cat >"$root/bin/ffmpeg" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RECORDING"
[[ ${FFMPEG_FAILS:-} == "${*: -1}" ]] && exit 1
: >"${*: -1}"
exit 0
EOF
chmod +x "$root/bin/ffprobe" "$root/bin/ffmpeg"

printf 'h264,video,0\naac,audio,0\n' >"$root/probe/compatible.mkv"
printf 'vp9,video,0\nopus,audio,0\n' >"$root/probe/vp9.webm"
printf 'h264,video,0\naac,audio,0\n' >"$root/probe/already.mp4"
printf 'mp3,audio,0\nmjpeg,video,1\n' >"$root/probe/withcover.mp3"
printf 'mp3,audio,0\n'               >"$root/probe/bare.mp3"

reset_inputs() {
  rm -rf -- "$root/work"
  mkdir -p "$root/work"
  for name in compatible.mkv vp9.webm already.mp4 withcover.mp3 bare.mp3; do
    printf 'input\n' >"$root/work/$name"
  done
}

run() {
  : >"$root/recording"
  (
    cd "$root/work" &&
      RECORDING=$root/recording PROBE_DIR=$root/probe PATH="$root/bin:$PATH" \
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
[[ $(calls) == *'dot.dir/clip.mp4'* ]] ||
  fail "the output belongs beside its input: $(calls)"
[[ ! -e $root/work/dot.mp4 ]] || fail 'the output escaped its directory'

# --- remux keeps what transcode keeps ------------------------------------

reset_inputs
run mp4 compatible.mkv >/dev/null
[[ $(calls) == *'-map 0:v:0'* && $(calls) == *"-map 0:a?"* ]] ||
  fail "a remux should select streams like the transcode does: $(calls)"

# --- usage ---------------------------------------------------------------

run >/dev/null 2>&1 && fail 'no arguments should be a usage error'
[[ $(run --help) == *'download'* ]] || fail 'help should point at the other command'

output=$(run webm compatible.mkv 2>&1 || true)
[[ $output == *'webm'* ]] || fail "an unsupported target should name it: $output"

printf 'convert-to tests passed\n'
