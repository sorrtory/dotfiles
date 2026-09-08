#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/common.sh"

readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_CONFIG_FILE="/etc/nix/nix.conf"
readonly NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
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
    . "$NIX_DAEMON_PROFILE"
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

  while IFS= read -r line; do
    case "$line" in
    '# Nix' | '# End Nix')
      return
      ;;
    esac
  done <"$path"

  return 1
}

is_uninstalled() {
  local id path

  for path in "${NIX_OWNED_PATHS[@]}"; do
    path_present "$path" && return 1
  done

  for path in "${NIX_SHELL_FILES[@]}"; do
    shell_file_has_nix_state "$path" && return 1
  done

  command -v getent >/dev/null 2>&1 || return 1
  getent group nixbld >/dev/null && return 1
  for id in {1..32}; do
    getent passwd "nixbld$id" >/dev/null && return 1
  done

  return 0
}

flakes_enabled() {
  local features

  features="$(nix config show experimental-features 2>/dev/null)"
  [[ " $features " == *' nix-command '* && " $features " == *' flakes '* ]]
}

check() {
  load_nix_profile

  if command -v nix >/dev/null 2>&1 &&
    multi_user_nix_installed &&
    flakes_enabled; then
    component_info "installed correctly: $(nix --version)"
    return
  fi

  if command -v nix >/dev/null 2>&1; then
    component_info "not installed correctly: $(nix --version)"
  else
    component_info 'not installed'
  fi
  return 1
}

enable_flakes() {
  flakes_enabled && return

  component_info 'enabling nix-command and flakes...'
  sudo tee --append "$NIX_CONFIG_FILE" >/dev/null <<'EOF'

extra-experimental-features = nix-command flakes
EOF
  sudo systemctl restart nix-daemon.service
}

install_nix() (
  local installer installer_dir

  require_commands curl sudo
  component_info 'validating sudo access...'
  sudo -v

  installer_dir="$(mktemp -d)"
  trap 'rm -rf -- "$installer_dir"' EXIT
  installer="$installer_dir/install-nix"

  component_info 'downloading the official Nix installer...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$installer" "$NIX_INSTALL_URL"

  component_info 'starting the multi-user Nix installation...'
  sh "$installer" --daemon --yes
)

install() {
  if check >/dev/null; then
    already_installed
    return 1
  fi

  load_nix_profile
  if ! command -v nix >/dev/null 2>&1 && ! is_uninstalled; then
    component_error 'partial Nix state exists; uninstall it explicitly before installing.'
    return 1
  fi

  if command -v nix >/dev/null 2>&1; then
    if ! multi_user_nix_installed; then
      component_error 'existing Nix installation is not a supported multi-user installation.'
      return 1
    fi
    require_commands sudo
    component_info 'validating sudo access...'
    sudo -v
  else
    install_nix
    load_nix_profile
  fi

  enable_flakes
  component_info "installed $(nix --version)"
  component_info 'open a new login shell before using Nix interactively.'
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
        component_error "cannot safely remove an incomplete Nix block from $path"
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
  if is_uninstalled; then
    already_uninstalled
    return 1
  fi

  local unit
  local -a units=()

  require_commands awk getent groupdel sed sudo systemctl userdel
  component_info 'validating sudo access...'
  sudo -v

  component_info 'stopping and disabling the Nix daemon...'
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

  component_info 'removing Nix shell startup references...'
  remove_shell_references

  component_info 'removing Nix-owned files...'
  # https://nix.dev/manual/nix/2.21/installation/uninstall#linux
  sudo rm -rf -- "${NIX_OWNED_PATHS[@]}"

  component_info 'removing Nix build users and group...'
  remove_build_users

  if ! is_uninstalled; then
    component_error 'uninstall finished with unrecognized or incomplete Nix state remaining.'
    return 1
  fi
  component_info 'uninstalled successfully.'
}

component_main "$@"
