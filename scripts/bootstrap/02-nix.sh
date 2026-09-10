#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_CONFIG_FILE="/etc/nix/nix.conf"
# Overridable so tests can neutralize it: the profile prepends the real Nix
# to PATH, which would otherwise shadow a mocked nix and run for real.
readonly NIX_DAEMON_PROFILE="${NIX_DAEMON_PROFILE:-/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
readonly -a NIX_SHELL_FILES=(
  /etc/bash.bashrc
  /etc/bashrc
  /etc/profile
  /etc/zsh/zshrc
  /etc/zshrc
)
readonly -a NIX_OWNED_PATHS=(
  /etc/nix
  /etc/profile.d/nix.sh
  /etc/tmpfiles.d/nix-daemon.conf
  /etc/systemd/system/nix-daemon.service
  /etc/systemd/system/nix-daemon.socket
  /etc/systemd/system/sockets.target.wants/nix-daemon.socket
  /nix
  /root/.nix-channels
  /root/.nix-defexpr
  /root/.nix-profile
)

load_nix_profile() {
  if [[ -e "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck disable=SC1090
    if ! . "$NIX_DAEMON_PROFILE"; then
      phase_error "cannot load the Nix daemon profile: $NIX_DAEMON_PROFILE"
      return 2
    fi
  fi
}

multi_user_nix_installed() {
  [[ -e "$NIX_DAEMON_PROFILE" && -S /nix/var/nix/daemon-socket/socket ]]
}

path_present() {
  [[ -e "$1" || -L "$1" ]]
}

shell_file_has_nix_state() {
  local line
  local path="$1"

  path_present "$path.backup-before-nix" && return
  [[ -f "$path" ]] || return 1
  if [[ ! -r "$path" ]]; then
    phase_error "cannot inspect Nix shell state: $path is not readable"
    return 2
  fi

  while IFS= read -r line; do
    case "$line" in
    '# Nix' | '# End Nix')
      return
      ;;
    esac
  done <"$path"

  return 1
}

nss_entry_absent() {
  local result
  local database="$1"
  local key="$2"

  if getent "$database" "$key" >/dev/null; then
    return 1
  else
    result=$?
  fi

  [[ $result -eq 2 ]] && return

  phase_error "cannot inspect $database entry $key: getent exited $result"
  return 2
}

is_uninstalled() {
  local id path result

  for path in "${NIX_OWNED_PATHS[@]}"; do
    path_present "$path" && return 1
  done

  for path in "${NIX_SHELL_FILES[@]}"; do
    if shell_file_has_nix_state "$path"; then
      return 1
    else
      result=$?
    fi
    [[ $result -eq 1 ]] || return "$result"
  done

  if ! command -v getent >/dev/null 2>&1; then
    phase_error 'cannot inspect Nix build accounts: getent is missing'
    return 2
  fi
  nss_entry_absent group nixbld || return $?
  for id in {1..32}; do
    nss_entry_absent passwd "nixbld$id" || return $?
  done

  return 0
}

flakes_enabled() {
  local features result

  if features="$(nix config show experimental-features 2>/dev/null)"; then
    :
  else
    result=$?
    phase_error "cannot inspect Nix experimental features: nix exited $result"
    return 2
  fi
  [[ " $features " == *' nix-command '* && " $features " == *' flakes '* ]]
}

check() {
  local result version

  load_nix_profile || return $?

  if ! command -v nix >/dev/null 2>&1; then
    phase_info 'not installed'
    return 1
  fi

  if version="$(nix --version 2>/dev/null)"; then
    :
  else
    result=$?
    phase_error "cannot inspect the Nix version: nix exited $result"
    return 2
  fi

  if ! multi_user_nix_installed; then
    phase_info "not installed correctly: $version"
    return 1
  fi

  if flakes_enabled; then
    phase_info "installed correctly: $version"
    return
  else
    result=$?
  fi

  [[ $result -eq 1 ]] || return "$result"
  phase_info "not installed correctly: $version"
  return 1
}

enable_flakes() {
  local result

  if flakes_enabled; then
    return
  else
    result=$?
  fi
  [[ $result -eq 1 ]] || return "$result"

  phase_info 'enabling nix-command and flakes...'
  sudo tee --append "$NIX_CONFIG_FILE" >/dev/null <<'EOF'

extra-experimental-features = nix-command flakes
EOF
  sudo systemctl restart nix-daemon.service
}

install_nix() (
  local installer installer_dir

  require_commands curl sudo
  phase_info 'validating sudo access...'
  sudo -v

  installer_dir="$(mktemp -d)"
  trap 'rm -rf -- "$installer_dir"' EXIT
  installer="$installer_dir/install-nix"

  phase_info 'downloading the official Nix installer...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$installer" "$NIX_INSTALL_URL"

  phase_info 'starting the multi-user Nix installation...'
  sh "$installer" --daemon --yes
)

install() {
  local result version

  require_commands curl git
  load_nix_profile
  if ! command -v nix >/dev/null 2>&1; then
    if is_uninstalled; then
      :
    else
      result=$?
      if [[ $result -eq 1 ]]; then
        phase_error 'partial Nix state exists; uninstall it explicitly before installing.'
        return 1
      fi
      return "$result"
    fi
  fi

  if command -v nix >/dev/null 2>&1; then
    if ! multi_user_nix_installed; then
      phase_error 'existing Nix installation is not a supported multi-user installation.'
      return 1
    fi
    require_commands sudo
    phase_info 'validating sudo access...'
    sudo -v
  else
    install_nix
    load_nix_profile
  fi

  enable_flakes
  if version="$(nix --version 2>/dev/null)"; then
    phase_info "installed $version"
  else
    result=$?
    phase_error "cannot inspect the installed Nix version: nix exited $result"
    return 2
  fi
  phase_info 'open a new login shell before using Nix interactively.'
}

remove_shell_references() {
  local backup path

  for path in "${NIX_SHELL_FILES[@]}"; do
    backup="$path.backup-before-nix"
    if [[ -f "$path" ]] && shell_file_has_nix_state "$path"; then
      if ! awk '
        /^# Nix$/ { if (inside) invalid = 1; inside = 1 }
        /^# End Nix$/ { if (!inside) invalid = 1; inside = 0 }
        END { exit invalid || inside }
      ' "$path"; then
        phase_error "cannot safely remove an incomplete Nix block from $path"
        return 1
      fi
      sudo sed --in-place '/^# Nix$/,/^# End Nix$/d' "$path"
    fi

    if path_present "$backup"; then
      sudo rm -f -- "$backup"
    fi
  done
}

remove_build_users() {
  local id user

  for id in {1..32}; do
    user="nixbld$id"
    if getent passwd "$user" >/dev/null; then
      sudo userdel "$user"
    fi
  done

  if getent group nixbld >/dev/null; then
    sudo groupdel nixbld
  fi
}

uninstall() {
  local result unit
  local -a units=()

  require_commands awk getent groupdel sed sudo systemctl userdel
  phase_info 'validating sudo access...'
  sudo -v

  phase_info 'stopping and disabling the Nix daemon...'
  if systemctl cat nix-daemon.service >/dev/null 2>&1; then
    sudo systemctl stop nix-daemon.service
  fi
  for unit in nix-daemon.socket nix-daemon.service; do
    if systemctl cat "$unit" >/dev/null 2>&1; then
      units+=("$unit")
    fi
  done
  if [[ ${#units[@]} -gt 0 ]]; then
    sudo systemctl disable "${units[@]}"
  fi
  sudo systemctl daemon-reload

  phase_info 'removing Nix shell startup references...'
  remove_shell_references

  phase_info 'removing Nix-owned files...'
  # https://nix.dev/manual/nix/2.21/installation/uninstall#linux
  sudo rm -rf -- "${NIX_OWNED_PATHS[@]}"

  phase_info 'removing Nix build users and group...'
  remove_build_users

  if is_uninstalled; then
    phase_info 'uninstalled successfully.'
    return
  else
    result=$?
  fi
  if [[ $result -eq 1 ]]; then
    phase_error 'uninstall finished with unrecognized or incomplete Nix state remaining.'
    return 1
  fi
  return "$result"
}

phase_main "$@"
