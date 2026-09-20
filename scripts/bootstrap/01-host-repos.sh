#!/usr/bin/env bash

set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

# Repository policy runs first so that every later phase installs from known
# endpoints rather than from whatever mirror a metalink happens to pick. It is
# deliberately not gated on which GPU the host has: mirror choice is a property
# of the network, and pinning it behind a graphics check left a Fedora machine
# with non-AMD graphics on the default mirrors.
readonly YANDEX='https://mirror.yandex.ru/fedora'
# Overridable so tests never write to the real host paths.
readonly OVERRIDE_DIR="${BOOTSTRAP_HOST_REPOS_OVERRIDE_DIR:-/etc/dnf/repos.override.d}"
readonly BACKUP_ROOT="${BOOTSTRAP_HOST_REPOS_BACKUP_DIR:-/root}"
readonly FEDORA_OVERRIDE="$OVERRIDE_DIR/80-yandex-fedora.repo"
readonly RPMFUSION_OVERRIDE="$OVERRIDE_DIR/81-yandex-rpmfusion.repo"

# RPM Fusion is repository configuration, so it is established here for every
# Fedora host rather than by a driver phase. It carries the freeworld codecs the
# AMD phase needs, and is also where an NVIDIA phase would find akmod-nvidia.
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

fedora_version() {
  rpm -E %fedora
}

host_matches() {
  [[ "$(uname -m)" == x86_64 ]] && is_fedora
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
  backup_dir="$BACKUP_ROOT/host-repos-backup-$(date +%Y%m%d-%H%M%S)"

  phase_info "backing up repository configuration to $backup_dir"
  sudo mkdir -p -- "$backup_dir"
  [[ -d /etc/yum.repos.d ]] && sudo cp -a -- /etc/yum.repos.d "$backup_dir/"
  [[ -d "$OVERRIDE_DIR" ]] && sudo cp -a -- "$OVERRIDE_DIR" "$backup_dir/"
  [[ -f /etc/dnf/dnf.conf ]] && sudo cp -a -- /etc/dnf/dnf.conf "$backup_dir/"
  sudo tee "$BACKUP_ROOT/host-repos-last-backup" >/dev/null <<<"$backup_dir"
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
  if ! host_matches; then
    phase_info 'not an x86_64 Fedora host; nothing to do'
    return
  fi

  require_commands rpm
  if [[ ! -e "$FEDORA_OVERRIDE" || ! -e "$RPMFUSION_OVERRIDE" ]]; then
    phase_info 'Yandex repo overrides are missing'
    return 1
  fi
  if ! rpm -q "${RPMFUSION_RELEASES[@]}" >/dev/null 2>&1; then
    phase_info 'RPM Fusion release packages are missing'
    return 1
  fi

  phase_info 'Fedora and RPM Fusion repositories are pinned to Yandex'
}

install() {
  local f

  if ! host_matches; then
    phase_info 'not an x86_64 Fedora host; nothing to do'
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

  # Repointing the mirrors leaves a package set assembled somewhere else, so
  # reconcile it here. This is also what makes the rest of the flow
  # deterministic: every later phase installs from these pinned endpoints.
  phase_info 'synchronizing the currently mixed Fedora package set'
  sudo dnf -y distro-sync --refresh

  phase_info 'updating Fedora base packages (this should also bring in the current Fedora kernel)'
  sudo dnf -y upgrade --refresh

  phase_info 'installing RPM Fusion release packages from Yandex'
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

  phase_info "repository backup recorded in $BACKUP_ROOT/host-repos-last-backup"
}

phase_main "$@"
