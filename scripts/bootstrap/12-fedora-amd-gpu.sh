#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Drivers only. Repository policy, including RPM Fusion, belongs to the
# host-repos phase, which runs first so this one can assume the freeworld
# packages are reachable.
readonly -a AMD_PACKAGES=(
  mesa-dri-drivers
  mesa-vulkan-drivers
  libva-utils
  vulkan-tools
  mpv
  linux-firmware
  amd-gpu-firmware
  amd-ucode-firmware
  kernel
  kernel-core
  kernel-modules
  kernel-modules-core
  kernel-modules-extra
)

readonly -a GSTREAMER_PACKAGES=(
  gstreamer1-plugin-libav
  gstreamer1-plugins-good
  gstreamer1-plugins-bad-free
  gstreamer1-plugins-bad-free-extras
  gstreamer1-plugins-bad-freeworld
  gstreamer1-plugins-ugly
)

readonly -a RPMFUSION_RELEASES=(
  rpmfusion-free-release
  rpmfusion-nonfree-release
)

host_os_id() {
  local os_release_file="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"
  local ID=''

  [[ -r "$os_release_file" ]] || return 1
  # shellcheck disable=SC1090
  . "$os_release_file"
  echo "${ID:-}"
}

is_fedora() {
  [[ "$(host_os_id 2>/dev/null || true)" == fedora ]]
}

# Matched on a PCI vendor ID rather than a text match, and treated as absent
# rather than fatal when lspci itself is unavailable: this only gates whether
# the phase applies, it must never block an unrelated host.
#
# A future NVIDIA phase is the same shape with vendor 10de and akmod-nvidia
# from the RPM Fusion nonfree repository that host-repos already establishes.
# Autodetection then needs no flag: each phase claims the host it matches.
gpu_vendor_present() {
  local vendor="$1"

  command -v lspci >/dev/null 2>&1 || return 1
  lspci -nnk 2>/dev/null | grep -Eiq "(VGA|3D|Display).*\[$vendor:"
}

amd_gpu_present() {
  gpu_vendor_present 1002
}

host_matches() {
  [[ "$(uname -m)" == x86_64 ]] && is_fedora && amd_gpu_present
}

show_mesa_versions() {
  rpm -q \
    mesa-libGL \
    mesa-dri-drivers \
    mesa-va-drivers \
    mesa-va-drivers-freeworld \
    mesa-vulkan-drivers 2>/dev/null || true
}

check() {
  local package

  if ! host_matches; then
    phase_info 'not a Fedora/AMD host; nothing to do'
    return
  fi

  require_commands rpm
  if ! rpm -q "${RPMFUSION_RELEASES[@]}" >/dev/null 2>&1; then
    phase_info 'RPM Fusion is not configured; run the host-repos phase first'
    return 1
  fi
  if ! rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
    phase_info 'mesa-va-drivers-freeworld is not installed'
    return 1
  fi
  for package in "${AMD_PACKAGES[@]}" "${GSTREAMER_PACKAGES[@]}"; do
    rpm -q "$package" >/dev/null 2>&1 || {
      phase_info "$package is not installed"
      return 1
    }
  done

  phase_info 'Fedora AMD Mesa/VA-API driver stack is installed'
}

install() {
  local freeworld

  if ! host_matches; then
    phase_info 'not a Fedora/AMD host; nothing to do'
    return
  fi

  require_commands sudo dnf rpm
  phase_info 'validating sudo access...'
  sudo -v

  # The freeworld packages live in RPM Fusion. Refusing here keeps the failure
  # at the missing prerequisite rather than in a confusing dnf resolution error.
  if ! rpm -q "${RPMFUSION_RELEASES[@]}" >/dev/null 2>&1; then
    phase_error 'RPM Fusion is not configured; run the host-repos phase first'
    return 1
  fi

  show_mesa_versions

  phase_info 'checking for mesa-va-drivers-freeworld in RPM Fusion'
  freeworld=$(dnf -q repoquery --available --latest-limit=1 \
    --qf '%{name}-%{evr}.%{arch}' mesa-va-drivers-freeworld 2>/dev/null | tail -n1 || true)
  if [[ -z "$freeworld" ]]; then
    phase_error 'mesa-va-drivers-freeworld is not visible; check RPM Fusion metadata before continuing'
    return 1
  fi

  if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
    phase_info 'mesa-va-drivers-freeworld is already installed; leaving it in place'
  elif rpm -q mesa-va-drivers >/dev/null 2>&1; then
    phase_info 'replacing Fedora mesa-va-drivers with RPM Fusion mesa-va-drivers-freeworld'
    # Intentionally NO --allowerasing here. If this cannot resolve cleanly,
    # stop instead of removing unrelated graphics packages.
    sudo dnf -y swap mesa-va-drivers mesa-va-drivers-freeworld
  else
    phase_info 'installing mesa-va-drivers-freeworld'
    sudo dnf -y install mesa-va-drivers-freeworld
  fi

  phase_info 'installing AMD graphics/video tools and current firmware/kernel packages'
  sudo dnf -y install "${AMD_PACKAGES[@]}"

  # Keep Fedora's ffmpeg-free stack, but complement the codec library from
  # RPM Fusion, avoiding a broad ffmpeg swap while still enabling H.264.
  if rpm -q ffmpeg-free >/dev/null 2>&1; then
    phase_info 'installing RPM Fusion libavcodec-freeworld to complement Fedora ffmpeg-free'
    sudo dnf -y install libavcodec-freeworld
  fi

  phase_info 'installing GStreamer codec/plugin packages'
  if ! sudo dnf -y install "${GSTREAMER_PACKAGES[@]}"; then
    phase_error 'GStreamer extras did not fully install; core AMD/kernel/VA-API setup can still be used'
  fi

  show_mesa_versions
  phase_info 'reboot before relying on the new kernel and VA-API driver'
}

phase_main "$@"
