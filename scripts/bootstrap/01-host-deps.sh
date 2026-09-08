#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Commands required by later bootstrap phases. This is the authoritative list.
readonly -a REQUIRED_COMMANDS=(
  curl
  git
)

check() {
  local -a missing=()

  mapfile -t missing < <(missing_commands "${REQUIRED_COMMANDS[@]}")
  if [[ ${#missing[@]} -gt 0 ]]; then
    phase_info "missing required commands: ${missing[*]}"
    return 1
  fi

  phase_info "required commands available: ${REQUIRED_COMMANDS[*]}"
}

install() {
  ensure_commands "${REQUIRED_COMMANDS[@]}"
}

phase_main "$@"
