#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Overridable so tests never read or change the host. The setup command comes
# from Home Manager's targets.genericLinux.gpu, which phase 04 activates; it
# points /run/opengl-driver at the Nixpkgs drivers and installs a tmpfiles.d
# rule, plus a GC root for it, so the link comes back after every reboot.
readonly SETUP="${BOOTSTRAP_NIX_GPU_SETUP:-$HOME/.nix-profile/bin/non-nixos-gpu-setup}"
readonly DRIVER_LINK="${BOOTSTRAP_NIX_GPU_LINK:-/run/opengl-driver}"
readonly TMPFILES_RULE="${BOOTSTRAP_NIX_GPU_TMPFILES:-/etc/tmpfiles.d/non-nixos-gpu.conf}"
readonly GC_ROOT="${BOOTSTRAP_NIX_GPU_GCROOT:-/nix/var/nix/gcroots/non-nixos-gpu.conf}"

# The rule the activated generation wants installed, and the drivers it links.
# Both live in the package the setup command belongs to.
expected_rule() {
  local setup

  setup="$(readlink -f -- "$SETUP")"
  printf '%s\n' "${setup%/bin/*}/lib/tmpfiles.d/non-nixos-gpu.conf"
}

expected_drivers() {
  local -a fields

  read -ra fields < <(grep -m 1 -- '/run/opengl-driver' "$(expected_rule)")
  printf '%s\n' "${fields[-1]}"
}

check() {
  local drivers

  if [[ ! -x "$SETUP" ]]; then
    phase_info 'no GPU setup command; run the home-manager phase first'
    return 1
  fi

  drivers="$(expected_drivers)"
  if [[ "$(readlink -- "$DRIVER_LINK" 2>/dev/null)" != "$drivers" ]]; then
    phase_info "$DRIVER_LINK is missing or points at other drivers"
    return 1
  fi
  if [[ "$(readlink -- "$TMPFILES_RULE" 2>/dev/null)" != "$(expected_rule)" ]]; then
    phase_info "$TMPFILES_RULE is missing or stale; the link would not survive a reboot"
    return 1
  fi
  phase_info 'Nix programs use the drivers of the activated configuration'
}

# shellcheck disable=SC2032 # the phase contract names this function install
install() {
  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi
  if [[ ! -x "$SETUP" ]]; then
    phase_error 'no GPU setup command; run the home-manager phase first'
    return 1
  fi

  require_commands sudo
  phase_info 'linking Nix GPU drivers...'
  # The resolved store path, because sudo's secure_path would not find the
  # profile, and root must run the exact generation that was activated.
  sudo "$(readlink -f -- "$SETUP")"
  phase_info 'restart Nix GPU programs, such as WezTerm, to use the drivers'
}

is_uninstalled() {
  [[ ! -L "$DRIVER_LINK" && ! -L "$TMPFILES_RULE" && ! -L "$GC_ROOT" ]]
}

uninstall() {
  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi

  require_commands sudo
  phase_info 'removing the Nix GPU driver link and its boot rule...'
  sudo rm -f -- "$TMPFILES_RULE" "$GC_ROOT" "$DRIVER_LINK"
}

phase_main "$@"
