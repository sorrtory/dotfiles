#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_DIR
# shellcheck disable=SC1091
. "$BOOTSTRAP_DIR/common/phase.sh"

TARGET_USER="$(id -un)"
readonly TARGET_USER
MANAGER=''
PACKAGES=()
DAEMONS=()

detect_host() {
  local ID='' ID_LIKE=''
  local release="${BOOTSTRAP_OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$release" ]] || { phase_error 'cannot read os-release'; return 2; }
  # shellcheck disable=SC1090
  . "$release"
  case " $ID $ID_LIKE " in
    *' debian '* | *' ubuntu '*)
      MANAGER=apt-get
      # qemu-kvm is a virtual package on Ubuntu; query its actual provider.
      PACKAGES=(qemu-system-x86 libvirt-daemon-system libvirt-clients virt-manager ovmf)
      ;;
    *' fedora '*)
      MANAGER=dnf
      PACKAGES=(qemu-kvm libvirt-daemon-kvm libvirt-daemon-config-network libvirt-client virt-manager edk2-ovmf)
      ;;
    *' arch '*)
      MANAGER=pacman
      PACKAGES=(qemu-desktop libvirt virt-manager dnsmasq edk2-ovmf)
      ;;
    *) phase_error "virtualization supports Debian/Ubuntu, Fedora and Arch; unsupported host: $ID"; return 2 ;;
  esac
  if [[ $(uname -m) != x86_64 ]]; then
    phase_error 'virtualization bootstrap currently supports x86_64 hosts'
    return 2
  fi
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

daemon_active() {
  systemctl is-active --quiet "$1.socket" || systemctl is-active --quiet "$1.service"
}

daemon_enabled() {
  systemctl is-enabled --quiet "$1.socket" || systemctl is-enabled --quiet "$1.service"
}

select_daemons() {
  # Preserve an existing layout. Fresh hosts prefer modular daemons when shipped.
  if daemon_active virtqemud; then
    DAEMONS=(virtqemud virtnetworkd virtstoraged virtnodedevd virtnwfilterd virtsecretd)
  elif daemon_active libvirtd; then
    DAEMONS=(libvirtd)
  elif daemon_enabled virtqemud; then
    DAEMONS=(virtqemud virtnetworkd virtstoraged virtnodedevd virtnwfilterd virtsecretd)
  elif daemon_enabled libvirtd; then
    DAEMONS=(libvirtd)
  elif [[ $(systemctl show --property=LoadState --value virtqemud.socket) == loaded ]]; then
    DAEMONS=(virtqemud virtnetworkd virtstoraged virtnodedevd virtnwfilterd virtsecretd)
  else
    DAEMONS=(libvirtd)
  fi
}

libvirt_group_member() {
  [[ " $(id -nG "$TARGET_USER") " == *' libvirt '* ]]
}

check() {
  local daemon network
  detect_host || return "$?"
  if ! packages_installed; then
    phase_info 'virtualization packages are missing'
    return 1
  fi
  select_daemons
  for daemon in "${DAEMONS[@]}"; do
    if ! systemctl is-enabled --quiet "$daemon.service" ||
      ! systemctl is-enabled --quiet "$daemon.socket" ||
      ! systemctl is-active --quiet "$daemon.socket" ||
      ! systemctl is-enabled --quiet "$daemon-ro.socket" ||
      ! systemctl is-active --quiet "$daemon-ro.socket"; then
      phase_info "$daemon is not enabled and listening"
      return 1
    fi
  done
  if getent group libvirt >/dev/null && ! libvirt_group_member; then
    phase_info "$TARGET_USER is not in the libvirt group"
    return 1
  fi
  if ! network=$(LC_ALL=C timeout 10 virsh --readonly --connect qemu:///system net-info default 2>/dev/null) ||
    ! grep -Eq '^Active:[[:space:]]+yes$' <<<"$network" ||
    ! grep -Eq '^Autostart:[[:space:]]+yes$' <<<"$network"; then
    phase_info 'default libvirt network is not active and set to autostart, or cannot be queried'
    return 1
  fi
  phase_info 'virtualization packages, local libvirt services and default network are configured'
  if [[ ! -c /dev/kvm ]]; then
    phase_info 'KVM acceleration unavailable: enable virtualization in firmware (or nested KVM in the outer host), then reboot'
  fi
}

install() {
  local daemon network active
  detect_host
  if [[ $EUID -eq 0 ]]; then
    phase_error 'run this phase as the target user, not as root'
    return 1
  fi
  require_commands sudo "$MANAGER" systemctl
  sudo -v
  if ! packages_installed; then
    phase_info 'installing distro QEMU/KVM, libvirt, virt-manager and UEFI firmware...'
    case "$MANAGER" in
      apt-get) sudo apt-get update; sudo apt-get install -y "${PACKAGES[@]}" ;;
      dnf) sudo dnf install -y "${PACKAGES[@]}" ;;
      pacman) sudo pacman -S --needed --noconfirm "${PACKAGES[@]}" ;;
    esac
  fi
  select_daemons
  for daemon in "${DAEMONS[@]}"; do
    sudo systemctl enable "$daemon.service"
    sudo systemctl enable --now "$daemon.socket"
    sudo systemctl enable --now "$daemon-ro.socket"
  done
  if getent group libvirt >/dev/null && ! libvirt_group_member; then
    sudo usermod -aG libvirt "$TARGET_USER"
    phase_info 'libvirt group membership applies after the next login'
  fi
  require_commands virsh
  # A working connection must precede checking whether the network exists.
  sudo virsh --connect qemu:///system list --all >/dev/null
  network=$(sudo virsh --connect qemu:///system net-list --all --name)
  if ! grep -qx default <<<"$network"; then
    if [[ ! -r /usr/share/libvirt/networks/default.xml ]]; then
      phase_error 'the distro default network XML is missing; define a libvirt network named default and retry'
      return 1
    fi
    sudo virsh --connect qemu:///system net-define /usr/share/libvirt/networks/default.xml
  fi
  active=$(sudo virsh --connect qemu:///system net-list --name)
  if ! grep -qx default <<<"$active"; then
    sudo virsh --connect qemu:///system net-start default
  fi
  sudo virsh --connect qemu:///system net-autostart default
  phase_info 'open virt-manager using qemu:///system; access follows the distro libvirt/polkit policy'
}

phase_main "$@"
