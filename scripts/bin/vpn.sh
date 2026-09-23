#!/usr/bin/env bash
# vpn — run one program through this machine's sing-box tunnel, TCP and UDP.
set -euo pipefail

die() { printf 'vpn: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: vpn [--] PROGRAM [ARGUMENT...]

Run PROGRAM with all of its traffic, including UDP and DNS, inside this
machine's VPN namespace. Other programs keep ordinary networking. If the
tunnel is down, PROGRAM loses network access instead of going direct.

Programs that sandbox themselves with user namespaces, such as Electron and
Chromium apps, need an AppArmor allowance on Ubuntu and abort without one.
Vesktop is managed and has one; other such apps are not supported yet.
EOF
}

case "${1-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
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
# When the last tunneled program has just exited, capture already has a stop
# job queued; the default job mode refuses a scope that needs it again.
exec "$VPN_SYSTEMD_RUN" --user --scope --quiet --collect --job-mode=replace \
  --unit="vpn-app-$(</proc/sys/kernel/random/uuid)" \
  --property=Requires=vpn-capture.service \
  --property=BindsTo=vpn-capture.service \
  --property=After=vpn-capture.service \
  "$VPN_ENTER" "$target" "$@"
