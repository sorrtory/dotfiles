#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

REPO_ROOT="$(cd -- "$BOOTSTRAP_DIR/../.." && pwd)"
readonly REPO_ROOT
# Overridable so tests can neutralize it: the profile prepends the real Nix
# to PATH, which would otherwise shadow a mocked nix and run for real.
readonly NIX_DAEMON_PROFILE="${NIX_DAEMON_PROFILE:-/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
readonly HOME_MANAGER_PROFILE="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/home-manager"
readonly HOME_MANAGER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
readonly HOME_MANAGER_FINGERPRINT_FILE="$HOME_MANAGER_STATE_DIR/home-manager-source.sha256"
readonly HOME_MANAGER_CONFIGURATION_FILE="$HOME_MANAGER_STATE_DIR/home-manager-configuration"

# A machine other than the default (the staging VM) must keep its own VPN
# identity, so a configuration chosen once through DOTFILES_HOME_CONFIGURATION
# is remembered rather than silently reverting to z on the next run.
selected_configuration() {
  local name=z

  if [[ -n "${DOTFILES_HOME_CONFIGURATION:-}" ]]; then
    name="$DOTFILES_HOME_CONFIGURATION"
  elif [[ -r "$HOME_MANAGER_CONFIGURATION_FILE" ]]; then
    name="$(<"$HOME_MANAGER_CONFIGURATION_FILE")"
  fi
  if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    phase_error "invalid Home Manager configuration name: $name"
    return 2
  fi
  echo "$name"
}

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
    {
      find flake.nix flake.lock home.nix modules packages -type f -print0
      if [[ -d scripts/bin ]]; then
        find scripts/bin -type f -print0
      fi
    } | sort -z
  )

  {
    echo "configuration $1"
    (
      cd -- "$REPO_ROOT"
      sha256sum "${source_files[@]}"
    )
  } | sha256sum | awk '{ print $1 }'
}

check() {
  local configuration current_fingerprint generation recorded_fingerprint

  configuration="$(selected_configuration)" || return 2
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

  current_fingerprint="$(configuration_fingerprint "$configuration")" || return 2
  recorded_fingerprint="$(<"$HOME_MANAGER_FINGERPRINT_FILE")"
  if [[ "$current_fingerprint" != "$recorded_fingerprint" ]]; then
    phase_info 'not activated from the current repository configuration'
    return 1
  fi

  generation="$(readlink -f -- "$HOME_MANAGER_PROFILE")" || return 2
  phase_info "activated: ${generation##*/} ($configuration)"
}

install() {
  local activation_dir configuration configuration_tmp fingerprint fingerprint_tmp result

  configuration="$(selected_configuration)" || return 2
  load_nix_profile
  require_commands nix
  activation_dir="$(mktemp -d)"

  phase_info "building the Home Manager configuration '$configuration'..."
  if nix build --out-link "$activation_dir/result" \
    "path:$REPO_ROOT#homeConfigurations.$configuration.activationPackage"; then
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

  if fingerprint="$(configuration_fingerprint "$configuration")"; then
    :
  else
    rm -rf -- "$activation_dir"
    return 2
  fi
  mkdir -p -- "$HOME_MANAGER_STATE_DIR"
  fingerprint_tmp="$(mktemp "$HOME_MANAGER_STATE_DIR/.home-manager-source.XXXXXX")"
  echo "$fingerprint" >"$fingerprint_tmp"
  mv -- "$fingerprint_tmp" "$HOME_MANAGER_FINGERPRINT_FILE"
  configuration_tmp="$(mktemp "$HOME_MANAGER_STATE_DIR/.home-manager-configuration.XXXXXX")"
  echo "$configuration" >"$configuration_tmp"
  mv -- "$configuration_tmp" "$HOME_MANAGER_CONFIGURATION_FILE"
  rm -rf -- "$activation_dir"
}

phase_main "$@"
