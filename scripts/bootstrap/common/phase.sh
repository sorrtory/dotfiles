#!/usr/bin/env bash

BOOTSTRAP_COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_COMMON_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_COMMON_DIR/output.sh"
# shellcheck disable=SC1091
. "$BOOTSTRAP_COMMON_DIR/packages.sh"

already_installed() {
  phase_info 'already satisfied; skipping'
}

already_uninstalled() {
  phase_error 'not installed; refusing to uninstall again.'
}

run_install() {
  local result

  if check >/dev/null; then
    already_installed
    return
  else
    result=$?
  fi

  if [[ $result -ne 1 ]]; then
    phase_error "status check failed with exit code $result"
    return "$result"
  fi

  install

  if check; then
    return
  else
    result=$?
  fi
  phase_error 'installation did not satisfy its status check'
  return "$result"
}

run_uninstall() {
  local result

  if is_uninstalled >/dev/null; then
    already_uninstalled
    return 1
  else
    result=$?
  fi

  if [[ $result -ne 1 ]]; then
    phase_error "uninstall status check failed with exit code $result"
    return "$result"
  fi

  uninstall

  if is_uninstalled; then
    return
  else
    result=$?
  fi
  phase_error 'uninstallation did not satisfy its status check'
  return "$result"
}

phase_main() {
  local command="${1:-}"

  if [[ $- != *e* || $- != *u* ]] || ! shopt -qo pipefail; then
    phase_error 'phase must enable: set -euo pipefail'
    return 70
  fi

  if [[ $# -ne 1 ]]; then
    phase_error 'usage: {status|install|uninstall}'
    return 64
  fi

  case "$command" in
  status)
    check
    ;;
  install)
    run_install
    ;;
  uninstall)
    if ! declare -F is_uninstalled >/dev/null &&
      ! declare -F uninstall >/dev/null; then
      phase_error 'phase does not support uninstall'
      return 1
    fi
    if ! declare -F is_uninstalled >/dev/null ||
      ! declare -F uninstall >/dev/null; then
      phase_error 'phase defines an incomplete uninstall contract'
      return 70
    fi
    run_uninstall
    ;;
  *)
    phase_error 'usage: {status|install|uninstall}'
    return 64
    ;;
  esac
}
