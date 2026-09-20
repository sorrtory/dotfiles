#!/usr/bin/env bash

# phase.sh sources this file, and a phase may source it again. Guard, because a
# second pass would fail on the readonly declarations below. Written as an `if`
# rather than `[[ ... ]] && return`, which would hand a failing status back to a
# caller running under `set -e`.
if [[ -n "${BOOTSTRAP_PACKAGES_SOURCED:-}" ]]; then
  return 0
fi
BOOTSTRAP_PACKAGES_SOURCED=1

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

host_package_manager() {
  local os_release_file="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"
  local ID=''
  local ID_LIKE=''

  if [[ ! -r "$os_release_file" ]]; then
    phase_error "cannot detect the host distribution: $os_release_file is not readable"
    return 1
  fi
  # shellcheck disable=SC1090
  . "$os_release_file"

  case " $ID $ID_LIKE " in
  *' debian '*) printf 'apt-get\n' ;;
  *' fedora '* | *' rhel '*) printf 'dnf\n' ;;
  *' arch '*) printf 'pacman\n' ;;
  *)
    phase_error "unsupported host distribution: ${ID:-unknown}"
    return 1
    ;;
  esac
}

# The CA bundle paths Nix's own profile script probes, in its order.  Nix only
# exports NIX_SSL_CERT_FILE when one of these exists, and without it every
# Nixpkgs-built curl and git rejects TLS with "unable to get local issuer
# certificate" even though the distro's trust store is present and dnf, gh and
# the system git are all working.
readonly -a CA_BUNDLE_PATHS=(
  /etc/ssl/certs/ca-certificates.crt
  /etc/ssl/ca-bundle.pem
  /etc/ssl/certs/ca-bundle.crt
  /etc/pki/tls/certs/ca-bundle.crt
)

ca_bundle_path() {
  local candidate
  local prefix="${BOOTSTRAP_CA_BUNDLE_PREFIX:-}"

  for candidate in "${CA_BUNDLE_PATHS[@]}"; do
    if [[ -e "$prefix$candidate" ]]; then
      printf '%s\n' "$prefix$candidate"
      return
    fi
  done

  return 1
}

# Host packages a later phase depends on, where being present is not enough and
# being current is the point. Install media can be old enough to break a phase
# that never names the package: Fedora 44's release ca-certificates does not own
# /etc/ssl/certs/ca-certificates.crt, the first path Nix probes for a CA bundle,
# so the flake's Nixpkgs git could not clone over TLS while dnf, gh and
# /usr/bin/git all worked.
#
# This refreshes the named packages rather than the system. A whole-system
# upgrade was tried and rejected: it is hostage to every enabled repository, and
# on this operator's network `dnf upgrade` fails outright on Cisco's openh264
# mirror, leaving the machine unbootstrapped over a package nothing here needs.
# When something else joins this class, add it to the caller's list; that is one
# line, not another bespoke probe.
ensure_current_packages() {
  local manager

  manager="$(host_package_manager)" || return 1
  require_commands sudo "$manager"
  phase_info "refreshing host packages: $*"

  case "$manager" in
  apt-get)
    sudo apt-get update
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade "$@" ||
      sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    ;;
  dnf)
    sudo dnf install -y --refresh "$@"
    sudo dnf upgrade -y "$@"
    ;;
  pacman)
    # Never -Sy: a partial upgrade is how an Arch host breaks. This installs a
    # missing package only; a stale one needs a full `pacman -Syu`, which is the
    # operator's to run, and the phase check says so rather than guessing.
    sudo pacman -S --needed --noconfirm "$@"
    ;;
  esac
}

ensure_commands() {
  local manager
  local -a missing=()

  mapfile -t missing < <(missing_commands "$@")
  # An explicit success: a bare `return` here would hand back the status of the
  # failed test, so a host that already has every command reported failure.
  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi

  manager="$(host_package_manager)" || return 1

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
