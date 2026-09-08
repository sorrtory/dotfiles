#!/usr/bin/env bash

BOOTSTRAP_COMMON_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_COMMON_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_COMMON_DIR/output.sh"
# shellcheck disable=SC1091
. "$BOOTSTRAP_COMMON_DIR/packages.sh"

run_install() {
  local probe_status

  if check >/dev/null; then
    phase_info 'already satisfied; skipping'
    return
  else
    probe_status=$?
  fi

  if [[ $probe_status -ne 1 ]]; then
    phase_error "status check failed with exit code $probe_status"
    return "$probe_status"
  fi

  install

  if check; then
    return
  else
    probe_status=$?
  fi

  if [[ $probe_status -ne 1 ]]; then
    phase_error "post-install status check failed with exit code $probe_status"
    return "$probe_status"
  fi
  phase_error 'installation did not satisfy its status check'
  return 1
}

run_uninstall() {
  local probe_status

  if is_uninstalled >/dev/null; then
    phase_error 'not installed; refusing to uninstall again.'
    return 1
  else
    probe_status=$?
  fi

  if [[ $probe_status -ne 1 ]]; then
    phase_error "uninstall status check failed with exit code $probe_status"
    return "$probe_status"
  fi

  uninstall

  if is_uninstalled; then
    return
  else
    probe_status=$?
  fi

  if [[ $probe_status -ne 1 ]]; then
    phase_error "post-uninstall status check failed with exit code $probe_status"
    return "$probe_status"
  fi
  phase_error 'uninstallation did not satisfy its status check'
  return 1
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
