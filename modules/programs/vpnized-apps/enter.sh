#!/usr/bin/env bash
# Private helper for the vpn command: place one already-resolved program inside
# the capture namespace. The caller owns the program's systemd scope.
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
  # Host loopback proxies are unreachable from this namespace, and capture
  # already carries all traffic, so an inherited proxy setting only breaks it.
  unset http_proxy https_proxy all_proxy ftp_proxy no_proxy
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY FTP_PROXY NO_PROXY
  setpriv=$(command -v setpriv)
  # The program gets the caller's PATH, not this helper's runtime inputs.
  PATH=$VPN_USER_PATH
  unset "${!VPN_@}"
  exec "$setpriv" --bounding-set=-all --inh-caps=-all --ambient-caps=-all \
    --no-new-privs -- "$@"
fi

[[ $EUID != 0 ]] || die 'run this command as your ordinary desktop user'
[[ ${1-} == /* && -f ${1-} && -x ${1-} ]] || die 'expected an absolute executable path'
: "${VPN_USER_PATH:?vpn: the vpn command must set VPN_USER_PATH}"
runtime=${VPN_CAPTURE_RUNTIME:-${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/vpn-capture}
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
[[ $holder =~ ^[1-9][0-9]*$ ]] ||
  die 'capture namespace did not start; see systemctl --user status vpn-capture. On Ubuntu, check ./scripts/bootstrap.sh status apparmor'
expected=$(readlink "/proc/$holder/ns/net") || die 'capture namespace disappeared'
[[ $expected != "$(readlink /proc/self/ns/net)" ]] || die 'capture did not isolate networking'
nsenter -U --preserve-credentials --keep-caps -n -t "$holder" \
  ip link show vpn0 >/dev/null 2>&1 || die 'TUN is not ready; host user-namespace policy may forbid it'

private=$(mktemp -d "$runtime/payload.XXXXXXXX")
# Capture failure may remove RuntimeDirectory before this scope finishes.
trap 'rm -f -- "$private/resolv.conf" "$private/nsswitch.conf"; rmdir -- "$private" 2>/dev/null || [[ ! -d $private ]]' EXIT
printf 'nameserver 172.31.255.2\noptions timeout:2 attempts:2\n' > "$private/resolv.conf"
awk '/^hosts:/ { print "hosts: files dns"; next } { print }' \
  /etc/nsswitch.conf > "$private/nsswitch.conf"
# The payload keeps this process's PID through every exec below. Electron moves
# its main process into a systemd scope of its own, so stopping this scope when
# capture fails would not reach it; this helper forwards the stop instead.
# Explicit stdin, because a background job otherwise reads /dev/null.
nsenter -U --preserve-credentials --keep-caps -n -t "$holder" \
  unshare --mount --propagation private \
  "$0" --inside "$private" "$expected" "$(id -u)" "$@" <&0 &
payload=$!
trap 'kill -TERM "$payload" 2>/dev/null' TERM HUP
# Ctrl-C reaches the payload directly; let it decide, and keep waiting.
trap : INT
status=0
while kill -0 "$payload" 2>/dev/null; do
  wait "$payload" && status=0 || status=$?
done
exit "$status"
