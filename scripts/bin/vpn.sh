#!/usr/bin/env bash
# vpn — run one program through this machine's sing-box tunnel, TCP and UDP.
set -euo pipefail

die() { printf 'vpn: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: vpn [--egress NAME --] PROGRAM [ARGUMENT...]

Run PROGRAM with all of its traffic, including UDP and DNS, inside this
machine's VPN namespace. Other programs keep ordinary networking. If the
tunnel is down, PROGRAM loses network access instead of going direct.

Programs that sandbox themselves with user namespaces, such as Electron and
Chromium apps, need an AppArmor allowance on Ubuntu and abort without one.
Vesktop is managed and has one; other such apps are not supported yet.
EOF
}

egress=
case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
  --egress)
    [[ $# -ge 4 && -n $2 && $3 == -- ]] || die 'usage: vpn --egress NAME -- PROGRAM [ARGUMENT...]'
    egress=$2
    shift 3 ;;
  --) shift ;;
esac
[[ $# -gt 0 ]] || die 'missing program'
[[ $EUID != 0 ]] || die 'run as your ordinary desktop user, not root'

# Resolve on the caller's own PATH: this script is packaged without runtime
# inputs and reaches its helpers through absolute paths instead. The invoked
# path is kept as is, because multicall tools dispatch on their argv[0] name.
target=$(command -v -- "$1") || die "command not found: $1"
shift
# command -v may return a relative path when the caller supplied one or PATH
# contains relative entries. Anchor it before systemd-run changes directory.
[[ $target == /* ]] || target=$PWD/$target
[[ -f $target && -x $target ]] || die "not an executable file: $target"
resolved=$(readlink -f -- "$target") || die "cannot resolve executable: $target"
case "$resolved" in
  /snap/*|/var/lib/flatpak/*|"$HOME"/.local/share/flatpak/*)
    die 'Snap and Flatpak programs are not supported' ;;
esac

export VPN_USER_PATH=$PATH
capture_unit=vpn-capture.service
if [[ -n $egress ]]; then
  [[ $egress =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die 'invalid egress name'
  control=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/vpn-control.json
  [[ -r $control && -O $control ]] || die 'private VPN inventory is unavailable'
  # jq reads $name inside its own filter, not from this shell.
  # shellcheck disable=SC2016
  "$VPN_JQ" -e --arg name "$egress" '.names | index($name) != null' "$control" >/dev/null 2>&1 ||
    die 'unknown egress name'
  # Hex keeps the instance reversible without systemd's path-style '-' and
  # backslash escaping changing an egress name on the D-Bus boundary.
  encoded=$(printf '%s' "$egress" | "$VPN_OD" -An -tx1 | "$VPN_TR" -d '[:space:]')
  capture_unit="vpn-capture@${encoded}.service"
  export VPN_CAPTURE_RUNTIME="$XDG_RUNTIME_DIR/vpn-capture-$encoded"
fi
# When the last tunneled program has just exited, capture already has a stop
# job queued; the default job mode refuses a scope that needs it again.
exec "$VPN_SYSTEMD_RUN" --user --scope --quiet --collect --job-mode=replace \
  --unit="vpn-app-$(</proc/sys/kernel/random/uuid)" \
  --property="Requires=$capture_unit" \
  --property="BindsTo=$capture_unit" \
  --property="After=$capture_unit" \
  "$VPN_ENTER" "$target" "$@"
