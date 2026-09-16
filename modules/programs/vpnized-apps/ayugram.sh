#!/usr/bin/env bash
# Managed AyuGram command: the terminal, the desktop icon and tg:// links all
# come here, so every launch starts or reaches AyuGram inside the VPN.
set -euo pipefail

proc=${VPN_PROC_ROOT:-/proc}
pid_file=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/vpn-capture/namespace.pid
holder=
if [[ -r $pid_file ]]; then
  read -r holder < "$pid_file" || true
fi

# A second launch, including a tg:// link, is handed to the instance that is
# already running. Reaching one outside the tunnel would bypass the VPN with
# no sign, and a running process cannot be moved into another network
# namespace, so refuse rather than guess or kill it. AyuGram is a single
# native binary, so its own resolved executable path identifies it; that path
# changes on every rebuild, so compare against this build's own, not a
# hardcoded one.
for dir in "$proc"/[0-9]*; do
  [[ -O $dir ]] || continue
  exe=$(readlink "$dir/exe" 2>/dev/null) || continue
  [[ $exe == "$VPN_AYUGRAM" ]] || continue
  if [[ ! $holder =~ ^[1-9][0-9]*$ || ! $dir/ns/net -ef $proc/$holder/ns/net ]]; then
    printf 'ayugram: AyuGram is already running outside the VPN (PID %s). Quit it, then start AyuGram again.\n' \
      "${dir##*/}" >&2
    exit 1
  fi
done

exec "$VPN_COMMAND" -- "$VPN_AYUGRAM" "$@"
