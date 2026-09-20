#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Commands required by later bootstrap phases. This is the authoritative list.
# The phase also guarantees a CA bundle at a path Nix probes, because phases 02
# and 03 fetch over TLS with Nixpkgs-built tools rather than the distro's. It
# gets there by upgrading host packages rather than by naming one.
readonly -a REQUIRED_COMMANDS=(
  curl
  git
  zsh
)

# Host packages that must be current rather than merely present. See
# ensure_current_packages for why this list exists and how to extend it.
readonly -a REQUIRED_PACKAGES=(
  ca-certificates
)

check() {
  local -a missing=()
  local bundle

  mapfile -t missing < <(missing_commands "${REQUIRED_COMMANDS[@]}")
  if [[ ${#missing[@]} -gt 0 ]]; then
    phase_info "missing required commands: ${missing[*]}"
    return 1
  fi

  if ! bundle="$(ca_bundle_path)"; then
    phase_info 'no CA bundle at a path Nix probes'
    return 1
  fi

  phase_info "required commands available: ${REQUIRED_COMMANDS[*]}"
  phase_info "CA bundle available at $bundle"
}

install() {
  local bundle

  ensure_commands "${REQUIRED_COMMANDS[@]}"

  if ! ca_bundle_path >/dev/null; then
    ensure_current_packages "${REQUIRED_PACKAGES[@]}"
  fi

  if ! bundle="$(ca_bundle_path)"; then
    phase_error "no CA bundle at any path Nix probes: ${CA_BUNDLE_PATHS[*]}"
    phase_error "refreshing ${REQUIRED_PACKAGES[*]} did not produce one; upgrade the host and retry"
    return 1
  fi

  phase_info "CA bundle available at $bundle"
}

phase_main "$@"
