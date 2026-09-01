#!/usr/bin/env bash

set -euo pipefail

readonly NIX_INSTALL_URL="https://nixos.org/nix/install"
readonly NIX_CONFIG_FILE="/etc/nix/nix.conf"
readonly FLAKES_CONFIG="extra-experimental-features = nix-command flakes"
readonly NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"

load_nix_profile() {
  if [[ -e "$NIX_DAEMON_PROFILE" ]]; then
    # Make a multi-user Nix installation visible in non-login shells.
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
  fi
}

system_flakes_enabled() {
  local features

  [[ -r "$NIX_CONFIG_FILE" ]] || return 1
  features="$(
    sed -nE \
      's/^[[:space:]]*(extra-)?experimental-features[[:space:]]*=[[:space:]]*(.*)$/\2/p' \
      "$NIX_CONFIG_FILE" | tr '\n' ' '
  )"

  [[ " $features " == *' nix-command '* && " $features " == *' flakes '* ]]
}

multi_user_nix_installed() {
  [[ -e "$NIX_DAEMON_PROFILE" && -S /nix/var/nix/daemon-socket/socket ]]
}

status() {
  load_nix_profile

  if ! command -v nix >/dev/null 2>&1; then
    printf 'not installed\n'
    return 1
  fi

  if ! multi_user_nix_installed; then
    printf '%s; not a multi-user daemon installation\n' "$(nix --version)"
    return 1
  fi

  if ! system_flakes_enabled; then
    printf '%s; flakes not enabled\n' "$(nix --version)"
    return 1
  fi

  printf '%s; flakes enabled\n' "$(nix --version)"
}

enable_flakes() {
  if system_flakes_enabled; then
    printf 'Flakes are already enabled.\n'
    return
  fi

  printf 'Enabling nix-command and flakes...\n'
  printf '\n%s\n' "$FLAKES_CONFIG" | sudo tee --append "$NIX_CONFIG_FILE" >/dev/null
  sudo systemctl restart nix-daemon.service
}

apply() {
  load_nix_profile

  if command -v nix >/dev/null 2>&1; then
    printf 'Nix is already installed: %s\n' "$(nix --version)"

    if ! multi_user_nix_installed; then
      printf 'Existing Nix installation is not a supported multi-user daemon installation.\n' >&2
      return 1
    fi

    if system_flakes_enabled; then
      printf 'Flakes are already enabled.\n'
      return
    fi

    if ! command -v sudo >/dev/null 2>&1; then
      printf 'Required command is missing: sudo\n' >&2
      return 1
    fi

    printf 'Validating sudo access...\n'
    sudo -v
    enable_flakes
    return
  fi

  if [[ "$(uname -s)" != "Linux" ]]; then
    printf 'This installer supports Linux only.\n' >&2
    return 1
  fi

  if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
    printf 'Multi-user Nix installation requires systemd.\n' >&2
    return 1
  fi

  if command -v getenforce >/dev/null 2>&1 && [[ "$(getenforce)" == "Enforcing" ]]; then
    printf 'The official multi-user Nix installer does not support enforcing SELinux.\n' >&2
    return 1
  fi

  local command_name
  for command_name in curl sudo; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      printf 'Required command is missing: %s\n' "$command_name" >&2
      return 1
    fi
  done

  # Authenticate before entering the unattended installer. This keeps
  # passwords out of the script and avoids a prompt halfway through setup.
  printf 'Validating sudo access...\n'
  sudo -v

  local installer
  installer_dir="$(mktemp -d)"
  trap 'rm -rf -- "$installer_dir"' EXIT
  installer="$installer_dir/install-nix"

  printf 'Downloading the official Nix installer...\n'
  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$installer" \
    "$NIX_INSTALL_URL"

  printf 'Starting the multi-user Nix installation...\n'
  sh "$installer" --daemon --yes

  load_nix_profile
  if ! multi_user_nix_installed; then
    printf 'Nix was installed, but the multi-user daemon is unavailable.\n' >&2
    return 1
  fi
  enable_flakes

  printf 'Installed %s\n' "$(nix --version)"
  printf 'Open a new login shell before using Nix interactively.\n'
}

case "${1:-}" in
  status)
    status
    ;;
  apply)
    apply
    ;;
  *)
    printf 'Usage: %s {status|apply}\n' "$0" >&2
    exit 64
    ;;
esac
