#!/usr/bin/env bash
# Managed Vesktop command: the terminal, the desktop icon and discord:// links
# all come here, so every launch starts or reaches Vesktop inside the VPN.
set -euo pipefail

proc=${VPN_PROC_ROOT:-/proc}
pid_file=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/vpn-capture/namespace.pid
holder=
if [[ -r $pid_file ]]; then
  read -r holder < "$pid_file" || true
fi

# A second launch, including a discord:// link, is handed to the instance that
# is already running. Reaching one outside the tunnel would bypass the VPN with
# no sign, and a running process cannot be moved into another network
# namespace, so refuse rather than guess or kill it.
for dir in "$proc"/[0-9]*; do
  [[ -O $dir ]] || continue
  mapfile -d '' -t argv 2>/dev/null < "$dir/cmdline" || continue
  # Only the main process: Electron's helpers carry --type=, and its sandboxed
  # children have their own network namespaces by design.
  [[ ${#argv[@]} -ge 2 && ${argv[1]} == */opt/Vesktop/resources/app.asar ]] || continue
  [[ " ${argv[*]} " != *' --type='* ]] || continue
  if [[ ! $holder =~ ^[1-9][0-9]*$ || ! $dir/ns/net -ef $proc/$holder/ns/net ]]; then
    printf 'vesktop: Vesktop is already running outside the VPN (PID %s). Quit it, then start Vesktop again.\n' \
      "${dir##*/}" >&2
    exit 1
  fi
done

exec "$VPN_COMMAND" -- "$VPN_VESKTOP" "$@"
