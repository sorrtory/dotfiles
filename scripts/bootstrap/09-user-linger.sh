#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

check() {
  local linger
  require_commands loginctl id
  if ! linger=$(loginctl show-user "$(id -un)" --property=Linger --value); then
    phase_error 'cannot inspect user linger'
    return 2
  fi
  case "$linger" in
    yes) phase_info 'user linger is enabled' ;;
    no) phase_info 'user linger is disabled'; return 1 ;;
    *) phase_error 'unexpected linger status'; return 2 ;;
  esac
}

install() {
  require_commands loginctl id
  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi
  phase_info 'enabling user services before login and after logout'
  loginctl enable-linger "$(id -un)"
}

# Linger serves all user services; removing the proxy does not establish that
# disabling linger is safe for the other services on this machine.
phase_main "$@"
