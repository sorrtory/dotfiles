#!/usr/bin/env bash
set -euo pipefail

case "${1-}" in
  ''|-h|--help)
    printf 'Usage: vpn [--] COMMAND [ARGUMENT...]\n\nRun an opt-in application through sing-box, including UDP.\nClose an existing Discord/Vesktop instance first. Other apps stay direct.\n'
    exit 0
    ;;
  --) shift ;;
esac
[[ $# -gt 0 ]] || { echo 'vpn: missing command' >&2; exit 2; }
[[ $EUID != 0 ]] || { echo 'vpn: run as your ordinary desktop user' >&2; exit 1; }
unit="vpn-app-$(cat /proc/sys/kernel/random/uuid)"
exec systemd-run --user --scope --quiet --collect --unit="$unit" \
  --property=Requires=vpn-capture.service \
  --property=BindsTo=vpn-capture.service \
  --property=After=vpn-capture.service \
  vpn-enter "$@"
