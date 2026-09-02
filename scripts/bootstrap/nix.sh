#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common.sh"

readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_CONFIG_FILE="/etc/nix/nix.conf"
readonly NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

load_nix_profile() {
  if [[ -e "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
  fi
}

multi_user_nix_installed() {
  [[ -e "$NIX_DAEMON_PROFILE" && -S /nix/var/nix/daemon-socket/socket ]]
}

flakes_enabled() {
  local features

  features="$(nix config show experimental-features)"
  [[ " $features " == *' nix-command '* && " $features " == *' flakes '* ]]
}

status() {
  load_nix_profile

  if command -v nix >/dev/null 2>&1 &&
    multi_user_nix_installed &&
    flakes_enabled; then
    printf 'installed correctly: %s\n' "$(nix --version)"
    return
  fi

  if command -v nix >/dev/null 2>&1; then
    printf 'not installed correctly: %s\n' "$(nix --version)"
  else
    printf 'not installed\n'
  fi
  return 1
}

enable_flakes() {
  flakes_enabled && return

  printf 'Enabling nix-command and flakes...\n'
  printf '\nextra-experimental-features = nix-command flakes\n' |
    sudo tee --append "$NIX_CONFIG_FILE" >/dev/null
  sudo systemctl restart nix-daemon.service
}

install_nix() {
  local installer installer_dir

  require_commands curl sudo
  printf 'Validating sudo access...\n'
  sudo -v

  installer_dir="$(mktemp -d)"
  trap 'rm -rf -- "$installer_dir"' EXIT
  installer="$installer_dir/install-nix"

  printf 'Downloading the official Nix installer...\n'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$installer" "$NIX_INSTALL_URL"

  printf 'Starting the multi-user Nix installation...\n'
  sh "$installer" --daemon --yes
  load_nix_profile
}

install() {
  load_nix_profile
  if command -v nix >/dev/null 2>&1; then
    if ! multi_user_nix_installed; then
      printf 'Existing Nix installation is not a supported multi-user installation.\n' >&2
      return 1
    fi
    require_commands sudo
    printf 'Validating sudo access...\n'
    sudo -v
  else
    install_nix
  fi

  enable_flakes
  printf 'Installed %s\n' "$(nix --version)"
  printf 'Open a new login shell before using Nix interactively.\n'
}

component_main Nix "$@"
