#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# The compiler and development headers that native desktop builds link against,
# owned by the distro rather than by Nix.
#
# Flutter's Linux desktop target is what forces the choice. Its build hardcodes
# CC=clang and CXX=clang++ and then compiles against GTK 3, so the compiler, the
# GTK headers and the C library underneath them all have to agree; on a non-NixOS
# host the only set that agrees is the distro's own. That also keeps Nixpkgs'
# clang out of the profile, where it could not have gone anyway: it collides with
# gcc over twenty names, from cc and c++ through every binutils name.
#
# A project that needs a particular Clang is not served by this phase and is not
# meant to be. A Nix development shell puts its own bin first on PATH, so it
# shadows the host compiler inside that project and nowhere else, as long as it
# brings the libraries it compiles against too.
#
# Android Studio needs none of this. The NDK ships its own Clang and
# android.toolchain.cmake names it by absolute path, so an Android build never
# consults PATH for a compiler.

MANAGER=''
PACKAGES=()
# Named absolutely rather than through PATH, because the Nix profile comes first
# there and this phase is about what the host itself provides.
HOST_CLANGXX="${BOOTSTRAP_HOST_CLANGXX:-/usr/bin/clang++}"
readonly HOST_CLANGXX
HOST_PKG_CONFIG="${BOOTSTRAP_HOST_PKG_CONFIG:-/usr/bin/pkg-config}"
readonly HOST_PKG_CONFIG

detect_host() {
  local ID='' ID_LIKE=''
  local release="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"

  if [[ ! -r "$release" ]]; then
    phase_error 'cannot read os-release'
    return 2
  fi
  # shellcheck disable=SC1090
  . "$release"

  case " $ID $ID_LIKE " in
  *' debian '* | *' ubuntu '*)
    MANAGER=apt-get
    # The set Flutter's own Linux instructions name, less the parts Nix already
    # provides (cmake, ninja, git). clang depends on the matching libstdc++
    # headers, so they arrive with it.
    PACKAGES=(clang libgtk-3-dev liblzma-dev pkg-config)
    ;;
  *' fedora '* | *' rhel '*)
    MANAGER=dnf
    # Fedora's clang requires gcc-c++ and libstdc++-devel outright, which is
    # where the C++ headers come from here.
    PACKAGES=(clang gtk3-devel xz-devel pkgconf-pkg-config)
    ;;
  *' arch '*)
    MANAGER=pacman
    # Arch keeps headers in the library packages themselves, so there is no
    # -devel half to name; gcc is listed because libstdc++'s headers live there.
    PACKAGES=(clang gcc gtk3 xz pkgconf)
    ;;
  *)
    phase_error "native-toolchain supports Debian/Ubuntu, Fedora and Arch; unsupported host: ${ID:-unknown}"
    return 2
    ;;
  esac
}

packages_installed() {
  local package status

  for package in "${PACKAGES[@]}"; do
    case "$MANAGER" in
    apt-get)
      status=$(dpkg-query --show --showformat='${db:Status-Abbrev}' "$package" 2>/dev/null) || return 1
      [[ $status == ii* ]] || return 1
      ;;
    dnf) rpm --quiet --query "$package" || return 1 ;;
    pacman) pacman -Q "$package" >/dev/null 2>&1 || return 1 ;;
    esac
  done
}

# Builds a GTK program the way a real build does: the host compiler, the host
# pkg-config, and the operator's ordinary PATH. That last part is the point.
# The Nix profile still puts ld, as and ar first on PATH and clang looks its
# linker up there, so a binary that carries /nix/store means the Nix linker
# answered and the two toolchains are mixing after all. Installing packages
# cannot fix that, so it is an error (2) rather than unfinished work (1).
toolchain_links_host_libraries() (
  local workdir flags
  local -a build_flags=()

  workdir="$(mktemp -d)" || return 2
  trap 'rm -rf -- "$workdir"' EXIT

  if ! flags="$("$HOST_PKG_CONFIG" --cflags --libs gtk+-3.0 2>/dev/null)"; then
    phase_info 'the host pkg-config cannot describe gtk+-3.0'
    return 1
  fi
  read -r -a build_flags <<<"$flags"

  cat >"$workdir/probe.cc" <<'PROBE'
#include <gtk/gtk.h>

int main(void) {
  return gtk_get_major_version() >= 3 ? 0 : 1;
}
PROBE

  if ! "$HOST_CLANGXX" -o "$workdir/probe" "$workdir/probe.cc" "${build_flags[@]}" >/dev/null 2>&1; then
    phase_info 'the host clang++ cannot build a GTK 3 program'
    return 1
  fi

  if LC_ALL=C grep -aq /nix/store "$workdir/probe"; then
    phase_error 'the host clang++ linked a binary reaching into /nix/store; the Nix linker or libraries answered for it'
    return 2
  fi
)

check() {
  detect_host || return "$?"

  if ! packages_installed; then
    phase_info "host toolchain packages are missing: ${PACKAGES[*]}"
    return 1
  fi

  if [[ ! -x "$HOST_CLANGXX" ]]; then
    phase_info "the host clang++ is not at $HOST_CLANGXX"
    return 1
  fi

  toolchain_links_host_libraries || return "$?"

  phase_info 'host clang, GTK 3 development files and pkg-config build and link a GTK program with no Nix in it'
}

install() {
  detect_host

  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi

  require_commands sudo "$MANAGER"
  sudo -v

  if ! packages_installed; then
    phase_info "installing the host native toolchain: ${PACKAGES[*]}"
    case "$MANAGER" in
    apt-get)
      sudo apt-get update
      sudo apt-get install -y "${PACKAGES[@]}"
      ;;
    dnf) sudo dnf install -y "${PACKAGES[@]}" ;;
    pacman) sudo pacman -S --needed --noconfirm "${PACKAGES[@]}" ;;
    esac
  fi

  phase_info 'a project needing another Clang overrides this one from a Nix development shell, not by replacing it'
}

phase_main "$@"
