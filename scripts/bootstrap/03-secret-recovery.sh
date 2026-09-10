#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/sops-config.sh"

REPO_ROOT="$(cd -- "$BOOTSTRAP_DIR/../.." && pwd)"
readonly REPO_ROOT
# Overridable so tests can neutralize it: the profile prepends the real Nix
# to PATH, which would otherwise shadow a mocked nix and run for real.
readonly NIX_DAEMON_PROFILE="${NIX_DAEMON_PROFILE:-/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh}"
readonly AGE_KEY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt"
readonly AGE_KEY_METADATA_FILE="${AGE_KEY_FILE}.recovery"
readonly SOPS_CONFIG_FILE="${SOPS_CONFIG_FILE:-$REPO_ROOT/.sops.yaml}"

load_nix_profile() {
  if [[ -r "$NIX_DAEMON_PROFILE" ]]; then
    # shellcheck disable=SC1090
    . "$NIX_DAEMON_PROFILE"
  fi
}

check() {
  local actual_hash expected_hash expected_recipient mode recipient

  # A repository that does not name exactly one recipient cannot be inspected,
  # which the phase contract distinguishes from being unsatisfied.
  expected_recipient="$(sops_config_recipient "$SOPS_CONFIG_FILE")" || return 2

  if [[ ! -f "$AGE_KEY_FILE" || -L "$AGE_KEY_FILE" ]]; then
    phase_info 'age identity is not recovered'
    return 1
  fi
  if [[ ! -f "$AGE_KEY_METADATA_FILE" || -L "$AGE_KEY_METADATA_FILE" ]]; then
    phase_info 'age identity recovery metadata is missing'
    return 1
  fi

  mode="$(stat -c '%a' "$AGE_KEY_FILE")" || return 2
  if [[ "$mode" != '600' ]]; then
    phase_info "age identity has unsafe mode $mode"
    return 1
  fi

  recipient="$(sed -n 's/^recipient=//p' "$AGE_KEY_METADATA_FILE")"
  expected_hash="$(sed -n 's/^sha256=//p' "$AGE_KEY_METADATA_FILE")"
  if [[ "$recipient" != "$expected_recipient" || -z "$expected_hash" ]]; then
    phase_info 'age identity recovery metadata does not match this repository'
    return 1
  fi

  actual_hash="$(sha256sum "$AGE_KEY_FILE")" || return 2
  actual_hash="${actual_hash%% *}"
  if [[ "$actual_hash" != "$expected_hash" ]]; then
    phase_info 'age identity changed after recovery'
    return 1
  fi

  phase_info 'age identity is recovered and verified'
}

install() {
  load_nix_profile
  require_commands nix
  nix run "path:$REPO_ROOT#recover-age-identity"
}

phase_main "$@"
