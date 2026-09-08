#!/usr/bin/env bash

missing_commands() {
  local command_name

  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || printf '%s\n' "$command_name"
  done
}

require_commands() {
  local -a missing=()

  mapfile -t missing < <(missing_commands "$@")

  if [[ ${#missing[@]} -gt 0 ]]; then
    phase_error "required commands are missing: ${missing[*]}"
    return 1
  fi
}

ensure_commands() {
  local manager
  local os_release_file="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"
  local ID=''
  local ID_LIKE=''
  local -a missing=()

  mapfile -t missing < <(missing_commands "$@")
  [[ ${#missing[@]} -gt 0 ]] || return

  if [[ ! -r "$os_release_file" ]]; then
    phase_error "cannot detect the host distribution: $os_release_file is not readable"
    return 1
  fi
  # shellcheck disable=SC1090
  . "$os_release_file"

  case " $ID $ID_LIKE " in
  *' debian '*) manager='apt-get' ;;
  *' fedora '* | *' rhel '*) manager='dnf' ;;
  *' arch '*) manager='pacman' ;;
  *)
    phase_error "unsupported host distribution: ${ID:-unknown}"
    return 1
    ;;
  esac

  require_commands sudo "$manager"
  phase_info "installing required host commands: ${missing[*]}"

  case "$manager" in
  apt-get)
    sudo apt-get update
    sudo apt-get install -y "${missing[@]}"
    ;;
  dnf)
    sudo dnf install -y "${missing[@]}"
    ;;
  pacman)
    sudo pacman -S --needed --noconfirm "${missing[@]}"
    ;;
  esac

  require_commands "${missing[@]}"
}
