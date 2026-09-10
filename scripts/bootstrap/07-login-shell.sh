#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

TARGET_USER="$(id -un)"
readonly TARGET_USER

host_zsh_path() {
  local candidate

  if [[ -n "${BOOTSTRAP_HOST_ZSH_PATH:-}" ]]; then
    [[ -x "$BOOTSTRAP_HOST_ZSH_PATH" ]] || return 1
    echo "$BOOTSTRAP_HOST_ZSH_PATH"
    return
  fi

  for candidate in /usr/bin/zsh /bin/zsh; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  return 1
}

host_bash_path() {
  local candidate

  if [[ -n "${BOOTSTRAP_HOST_BASH_PATH:-}" ]]; then
    [[ -x "$BOOTSTRAP_HOST_BASH_PATH" ]] || return 1
    echo "$BOOTSTRAP_HOST_BASH_PATH"
    return
  fi

  for candidate in /usr/bin/bash /bin/bash; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  return 1
}

current_login_shell() {
  local passwd_entry

  passwd_entry="$(getent passwd "$TARGET_USER")" || return 1
  echo "${passwd_entry##*:}"
}

check() {
  local current_shell zsh_path

  require_commands getent id readlink
  if ! zsh_path="$(host_zsh_path)"; then
    phase_info 'host Zsh is not installed'
    return 1
  fi
  if ! current_shell="$(current_login_shell)"; then
    phase_error "cannot read the login shell for $TARGET_USER"
    return 2
  fi

  if [[ "$(readlink -f -- "$current_shell")" != "$(readlink -f -- "$zsh_path")" ]]; then
    phase_info "login shell is $current_shell, not $zsh_path"
    return 1
  fi

  phase_info "login shell is $current_shell"
}

install() {
  local zsh_path

  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi

  require_commands getent id sudo
  if ! zsh_path="$(host_zsh_path)"; then
    phase_error 'host Zsh is missing; run the host-deps phase first'
    return 1
  fi

  phase_info "setting $zsh_path as the login shell for $TARGET_USER..."
  sudo usermod --shell "$zsh_path" "$TARGET_USER"
  phase_info 'the login-shell change applies after the next login'
}

is_uninstalled() {
  local bash_path current_shell

  require_commands getent id readlink
  if ! bash_path="$(host_bash_path)"; then
    phase_error 'host Bash is not installed'
    return 2
  fi
  if ! current_shell="$(current_login_shell)"; then
    phase_error "cannot read the login shell for $TARGET_USER"
    return 2
  fi

  [[ "$(readlink -f -- "$current_shell")" == "$(readlink -f -- "$bash_path")" ]]
}

uninstall() {
  local bash_path

  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi

  require_commands getent id sudo
  if ! bash_path="$(host_bash_path)"; then
    phase_error 'host Bash is missing'
    return 1
  fi

  phase_info "restoring $bash_path as the login shell for $TARGET_USER..."
  sudo usermod --shell "$bash_path" "$TARGET_USER"
  phase_info 'the login-shell change applies after the next login'
}

phase_main "$@"
