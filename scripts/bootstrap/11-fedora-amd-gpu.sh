#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/packages.sh"

readonly YANDEX='https://mirror.yandex.ru/fedora'
# Overridable so tests never write to the real host paths.
readonly OVERRIDE_DIR="${BOOTSTRAP_FEDORA_AMD_OVERRIDE_DIR:-/etc/dnf/repos.override.d}"
readonly BACKUP_ROOT="${BOOTSTRAP_FEDORA_AMD_BACKUP_DIR:-/root}"
readonly FEDORA_OVERRIDE="$OVERRIDE_DIR/80-yandex-fedora.repo"
readonly RPMFUSION_OVERRIDE="$OVERRIDE_DIR/81-yandex-rpmfusion.repo"

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

fedora_version() {
  rpm -E %fedora
}

# Matched on the AMD/ATI PCI vendor ID rather than a text match, and treated
# as absent rather than fatal when lspci itself is unavailable: this only
# gates whether the phase applies, it must never block an unrelated host.
amd_gpu_present() {
  command -v lspci >/dev/null 2>&1 || return 1
  lspci -nnk 2>/dev/null | grep -Eiq '(VGA|3D|Display).*\[1002:'
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

check_url() {
  phase_info "checking $1..."
  curl -fsSL --connect-timeout 10 --max-time 30 -o /dev/null "$1"
}

preflight_mirrors() {
  local f a url
  f="$(fedora_version)"
  a="$(rpm -E %_arch)"

  phase_info 'checking Yandex mirror endpoints before touching DNF configuration'
  for url in \
    "$YANDEX/linux/releases/$f/Everything/$a/os/repodata/repomd.xml" \
    "$YANDEX/linux/updates/$f/Everything/$a/repodata/repomd.xml" \
    "$YANDEX/rpmfusion/free/fedora/rpmfusion-free-release-$f.noarch.rpm" \
    "$YANDEX/rpmfusion/nonfree/fedora/rpmfusion-nonfree-release-$f.noarch.rpm" \
    "$YANDEX/rpmfusion/free/fedora/releases/$f/Everything/$a/os/repodata/repomd.xml" \
    "$YANDEX/rpmfusion/free/fedora/updates/$f/$a/repodata/repomd.xml" \
    "$YANDEX/rpmfusion/nonfree/fedora/releases/$f/Everything/$a/os/repodata/repomd.xml" \
    "$YANDEX/rpmfusion/nonfree/fedora/updates/$f/$a/repodata/repomd.xml"; do
    check_url "$url" || {
      phase_error 'mirror preflight failed; no repository files were changed'
      return 1
    }
  done
}

backup_repos() {
  local backup_dir
  backup_dir="$BACKUP_ROOT/fedora-amd-repo-backup-$(date +%Y%m%d-%H%M%S)"

  phase_info "backing up repository configuration to $backup_dir"
  sudo mkdir -p -- "$backup_dir"
  [[ -d /etc/yum.repos.d ]] && sudo cp -a -- /etc/yum.repos.d "$backup_dir/"
  [[ -d "$OVERRIDE_DIR" ]] && sudo cp -a -- "$OVERRIDE_DIR" "$backup_dir/"
  [[ -f /etc/dnf/dnf.conf ]] && sudo cp -a -- /etc/dnf/dnf.conf "$backup_dir/"
  sudo tee "$BACKUP_ROOT/fedora-amd-last-repo-backup" >/dev/null <<<"$backup_dir"
}

write_fedora_override() {
  phase_info 'pinning Fedora base + updates to Yandex, disabling the Cisco OpenH264 repo'
  sudo mkdir -p -- "$OVERRIDE_DIR"
  sudo tee "$FEDORA_OVERRIDE" >/dev/null <<REPO
[fedora]
baseurl=$YANDEX/linux/releases/\$releasever/Everything/\$basearch/os/
metalink=
mirrorlist=
skip_if_unavailable=False

[updates]
baseurl=$YANDEX/linux/updates/\$releasever/Everything/\$basearch/
metalink=
mirrorlist=
skip_if_unavailable=False

[fedora-cisco-openh264]
enabled=0
REPO
}

write_rpmfusion_override() {
  phase_info 'pinning RPM Fusion Free + Nonfree to Yandex'
  sudo mkdir -p -- "$OVERRIDE_DIR"
  sudo tee "$RPMFUSION_OVERRIDE" >/dev/null <<REPO
[rpmfusion-free]
baseurl=$YANDEX/rpmfusion/free/fedora/releases/\$releasever/Everything/\$basearch/os/
metalink=
mirrorlist=
skip_if_unavailable=False

[rpmfusion-free-updates]
baseurl=$YANDEX/rpmfusion/free/fedora/updates/\$releasever/\$basearch/
metalink=
mirrorlist=
skip_if_unavailable=False

[rpmfusion-nonfree]
baseurl=$YANDEX/rpmfusion/nonfree/fedora/releases/\$releasever/Everything/\$basearch/os/
metalink=
mirrorlist=
skip_if_unavailable=False

[rpmfusion-nonfree-updates]
baseurl=$YANDEX/rpmfusion/nonfree/fedora/updates/\$releasever/\$basearch/
metalink=
mirrorlist=
skip_if_unavailable=False
REPO
}

refresh_cache() {
  sudo dnf clean all
  sudo dnf makecache --refresh
}

check() {
  local package

  if ! host_matches; then
    phase_info 'not a Fedora/AMD host; nothing to do'
    return
  fi

  require_commands rpm
  if [[ ! -e "$FEDORA_OVERRIDE" || ! -e "$RPMFUSION_OVERRIDE" ]]; then
    phase_info 'Yandex repo overrides are missing'
    return 1
  fi
  if ! rpm -q rpmfusion-free-release rpmfusion-nonfree-release >/dev/null 2>&1; then
    phase_info 'RPM Fusion release packages are missing'
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

  require_commands curl sudo dnf rpm
  phase_info 'validating sudo access...'
  sudo -v

  preflight_mirrors
  backup_repos
  write_fedora_override

  phase_info 'refreshing Fedora metadata from Yandex'
  refresh_cache

  phase_info 'synchronizing the currently mixed Fedora package set'
  sudo dnf -y distro-sync --refresh

  phase_info 'updating Fedora base packages (this should also bring in the current Fedora kernel)'
  sudo dnf -y upgrade --refresh

  phase_info 'installing RPM Fusion release packages from Yandex'
  local f
  f="$(fedora_version)"
  sudo dnf -y install \
    "$YANDEX/rpmfusion/free/fedora/rpmfusion-free-release-$f.noarch.rpm" \
    "$YANDEX/rpmfusion/nonfree/fedora/rpmfusion-nonfree-release-$f.noarch.rpm"

  write_rpmfusion_override

  phase_info 'refreshing Fedora + RPM Fusion metadata'
  refresh_cache

  phase_info 'synchronizing once more now that RPM Fusion is available'
  sudo dnf -y distro-sync --refresh
  sudo dnf -y upgrade --refresh

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

  phase_info 'final update pass'
  sudo dnf -y upgrade --refresh

  show_mesa_versions
  phase_info 'reboot before relying on the new kernel and VA-API driver'
  phase_info "repository backup recorded in $BACKUP_ROOT/fedora-amd-last-repo-backup"
}

phase_main "$@"
