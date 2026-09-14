#!/usr/bin/env bash
# Managed Vesktop command: the terminal, the desktop icon and discord:// links
# all come here, so every launch starts or reaches Vesktop inside the VPN.
set -euo pipefail

exec "$VPN_COMMAND" -- "$VPN_VESKTOP" "$@"
