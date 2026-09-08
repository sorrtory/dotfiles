#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

REPO_ROOT="$(cd -- "$BOOTSTRAP_DIR/../.." && pwd)"
readonly REPO_ROOT
readonly NIX_DAEMON_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
readonly HOME_MANAGER_PROFILE="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
readonly HOME_MANAGER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly HOME_MANAGER_FINGERPRINT_FILE="$HOME_MANAGER_STATE_DIR/home-manager-source.sha256"
readonly HOME_MANAGER_FLAKE="path:$REPO_ROOT#homeConfigurations.z.activationPackage"

load_nix_profile() {
  if [[ -r "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
  fi
}

configuration_fingerprint() {
  local -a source_files=()

  mapfile -d '' -t source_files < <(
    cd -- "$REPO_ROOT"
    find flake.nix flake.lock home.nix modules packages -type f -print0 | sort -z
  )

  (
    cd -- "$REPO_ROOT"
    sha256sum "${source_files[@]}"
  ) | sha256sum | awk '{ print $1 }'
}

check() {
  local current_fingerprint generation recorded_fingerprint

  load_nix_profile
  if ! command -v nix >/dev/null 2>&1; then
    phase_info 'not activated: Nix is unavailable'
    return 1
  fi
  if [[ ! -L "$HOME_MANAGER_PROFILE" || ! -x "$HOME_MANAGER_PROFILE/activate" ]]; then
    phase_info 'not activated'
    return 1
  fi
  if [[ ! -r "$HOME_MANAGER_FINGERPRINT_FILE" ]]; then
    phase_info 'not activated from the current repository configuration'
    return 1
  fi

  current_fingerprint="$(configuration_fingerprint)" || return 2
  recorded_fingerprint="$(<"$HOME_MANAGER_FINGERPRINT_FILE")"
  if [[ "$current_fingerprint" != "$recorded_fingerprint" ]]; then
    phase_info 'not activated from the current repository configuration'
    return 1
  fi

  generation="$(readlink -f -- "$HOME_MANAGER_PROFILE")" || return 2
  phase_info "activated: ${generation##*/}"
}

install() {
  local activation_dir fingerprint fingerprint_tmp result

  load_nix_profile
  require_commands nix
  activation_dir="$(mktemp -d)"

  phase_info 'building the Home Manager configuration...'
  if nix build --out-link "$activation_dir/result" "$HOME_MANAGER_FLAKE"; then
    :
  else
    result=$?
    rm -rf -- "$activation_dir"
    return "$result"
  fi

  phase_info 'activating the Home Manager configuration...'
  if "$activation_dir/result/activate"; then
    :
  else
    result=$?
    rm -rf -- "$activation_dir"
    return "$result"
  fi

  if fingerprint="$(configuration_fingerprint)"; then
    :
  else
    rm -rf -- "$activation_dir"
    return 2
  fi
  mkdir -p -- "$HOME_MANAGER_STATE_DIR"
  fingerprint_tmp="$(mktemp "$HOME_MANAGER_STATE_DIR/.home-manager-source.XXXXXX")"
  echo "$fingerprint" >"$fingerprint_tmp"
  mv -- "$fingerprint_tmp" "$HOME_MANAGER_FINGERPRINT_FILE"
  rm -rf -- "$activation_dir"
}

phase_main "$@"
