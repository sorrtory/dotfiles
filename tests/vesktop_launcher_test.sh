#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$root/vpn" <<'EOF'
#!/usr/bin/env bash
if [[ ${1-} == --capture-path ]]; then
  printf '%s/vpn-capture\n' "$XDG_RUNTIME_DIR"
  exit 0
fi
printf '%s\n' "$@" > "$TEST_ROOT/launched"
EOF
chmod +x "$root/vpn"
: > "$root/ns-session"
: > "$root/ns-capture"
mkdir -p "$root/run/vpn-capture"

# A fake /proc entry: its argv and the namespace file its ns/net resolves to.
process() {
  local pid=$1 namespace=$2
  shift 2
  mkdir -p "$root/proc/$pid/ns"
  printf '%s\0' "$@" > "$root/proc/$pid/cmdline"
  ln -sfn "$root/$namespace" "$root/proc/$pid/ns/net"
}
asar=/nix/store/abc-vesktop/opt/Vesktop/resources/app.asar
launch() {
  rm -f "$root/launched"
  TEST_ROOT=$root VPN_PROC_ROOT=$root/proc XDG_RUNTIME_DIR=$root/run \
    VPN_COMMAND=$root/vpn VPN_VESKTOP=/raw/vesktop \
    bash "$repo/modules/programs/vpnized-apps/vesktop.sh" "$@"
}

process 7 ns-capture sing-box run
launch 'discord://-/channels/1' || fail 'cold start refused'
[[ $(<"$root/launched") == $'--app\nvesktop\n--\n/raw/vesktop\ndiscord://-/channels/1' ]] ||
  fail 'launcher did not hand the raw package and arguments to vpn'

process 20 ns-session /nix/store/other-app/bin/electron /nix/store/other/resources/app.asar
process 21 ns-session "/nix/store/e/electron --type=renderer --app-path=$asar --lang=en-US"
launch || fail 'unrelated apps or Electron helpers caused a refusal'

# Real shape on staging: Chromium rewrites the main process's command line into
# one space-joined string with flags before the app path.
printf '7\n' > "$root/run/vpn-capture/namespace.pid"
process 30 ns-capture "/nix/store/e/electron --enable-speech-dispatcher $asar"
launch || fail 'refused an instance already inside capture'

process 31 ns-session "/nix/store/e/electron --enable-speech-dispatcher $asar"
if output=$(launch 2>&1); then fail 'handed off to an untunneled instance'; fi
[[ $output == *'(PID 31)'* ]] || fail 'refusal does not name the PID'
[[ ! -e $root/launched ]] || fail 'vpn ran despite the refusal'
rm -rf "$root/proc/31"

# The unrewritten form, one argument per NUL, is refused the same way.
process 32 ns-session /nix/store/e/electron --enable-speech-dispatcher "$asar"
if launch 2>/dev/null; then fail 'handed off to an untunneled instance with a NUL-separated argv'; fi
rm -rf "$root/proc/32"

rm "$root/run/vpn-capture/namespace.pid"
if launch 2>/dev/null; then fail 'accepted an instance while capture is not running'; fi
echo 'PASS: Vesktop launcher refuses untunneled instances only'
