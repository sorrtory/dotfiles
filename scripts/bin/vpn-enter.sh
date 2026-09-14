#!/usr/bin/env bash
set -euo pipefail
umask 077

die() { printf 'vpn: %s\n' "$*" >&2; exit 1; }

# This branch runs with capabilities only in the capture's user namespace.
# Private mounts affect this payload's descendants, never the host resolver.
if [[ ${1-} == --inside ]]; then
  shift
  private=$1 expected=$2 expected_uid=$3
  shift 3
  [[ $(id -u) == "$expected_uid" ]] || die 'namespace changed the payload UID'
  [[ $(readlink /proc/self/ns/net) == "$expected" ]] || die 'wrong network namespace'
  mount --bind "$private/resolv.conf" /etc/resolv.conf
  mount --bind "$private/nsswitch.conf" /etc/nsswitch.conf
  unset http_proxy https_proxy all_proxy ftp_proxy no_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY FTP_PROXY NO_PROXY
  exec setpriv --bounding-set=-all --inh-caps=-all --ambient-caps=-all \
    --no-new-privs -- "$@"
fi

[[ $EUID != 0 ]] || die 'run this command as your ordinary desktop user'
[[ $# -gt 0 ]] || die 'missing command'
runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/vpn-capture
holder=
for ((attempt = 0; attempt < 100; attempt++)); do
  if [[ -r $runtime/namespace.pid ]]; then
    read -r holder < "$runtime/namespace.pid" || true
    if [[ $holder =~ ^[1-9][0-9]*$ && -e /proc/$holder/ns/net ]] &&
      nsenter -U --preserve-credentials --keep-caps -n -t "$holder" \
        ip link show vpn0 >/dev/null 2>&1; then
      break
    fi
  fi
  sleep 0.1
done
[[ $holder =~ ^[1-9][0-9]*$ ]] || die 'capture namespace did not start; inspect vpn-capture.service'
expected=$(readlink "/proc/$holder/ns/net") || die 'capture namespace disappeared'
[[ $expected != "$(readlink /proc/self/ns/net)" ]] || die 'capture did not isolate networking'
nsenter -U --preserve-credentials --keep-caps -n -t "$holder" \
  ip link show vpn0 >/dev/null 2>&1 || die 'TUN is not ready; host user-namespace policy may forbid it'

name=$1
shift
if [[ $name == discord ]] && ! command -v discord >/dev/null 2>&1; then
  name=vesktop
fi
target=$(command -v -- "$name") || die "command not found: $name"
[[ -f $target && -x $target ]] || die 'target must be an executable file'
canonical=$(realpath -- "$target")
# Preserve the invoked basename: multicall tools such as coreutils dispatch
# through argv[0], and executing their canonical symlink target breaks that.
case "$canonical" in
  /snap/*|*/snap|*/flatpak) die 'Snap and Flatpak launchers are not supported yet' ;;
esac

# Electron can silently hand the request to an existing, untunneled instance.
# Check executable paths, not command lines (which may contain private data).
case "${canonical##*/}" in
  vesktop|Discord|discord)
    for process in /proc/[0-9]*; do
      [[ $(readlink "$process/exe" 2>/dev/null || true) == "$canonical" ]] || continue
      [[ $(readlink "$process/ns/net" 2>/dev/null || true) == "$expected" ]] ||
        die "close the existing ${target##*/} instance (PID ${process##*/}) before VPN launch"
    done
    ;;
esac

private=$(mktemp -d "$runtime/payload.XXXXXXXX")
# Capture failure may remove RuntimeDirectory before this scope finishes.
trap 'rm -f -- "$private/resolv.conf" "$private/nsswitch.conf"; rmdir -- "$private" 2>/dev/null || [[ ! -d $private ]]' EXIT
printf 'nameserver 172.31.255.2\noptions timeout:2 attempts:2\n' > "$private/resolv.conf"
awk '/^hosts:/ { print "hosts: files dns"; next } { print }' \
  /etc/nsswitch.conf > "$private/nsswitch.conf"
nsenter -U --preserve-credentials --keep-caps -n -t "$holder" \
  unshare --mount --propagation private \
  "$0" --inside "$private" "$expected" "$(id -u)" "$target" "$@"
