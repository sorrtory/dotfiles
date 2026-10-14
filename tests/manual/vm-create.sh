#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Run on the libvirt host after vm-create returns successfully. This changes
# only the named disposable guest by rebooting it; it never creates/deletes one.
if (($# < 1 || $# > 2)); then
  printf 'Usage: %s DISPOSABLE_VM [DISALLOWED_HOST_IPV4]\n' "$0" >&2
  exit 2
fi
vm_create_name=$1
vm_create_denied_source=${2:-}
vm_create_identity=${VM_CREATE_TEST_IDENTITY:-$HOME/.config/sops-nix/secrets/id_ed25519_servers}
vm_create_user=${VM_CREATE_TEST_USER:-$(id -un)}
v() { timeout 15 virsh --connect qemu:///system "$@"; }
vm_create_uuid=$(v domuuid "$vm_create_name")
vm_create_cache="${XDG_CACHE_HOME:-$HOME/.cache}/vm-create"
vm_create_ssh=(ssh -T -n -i "$vm_create_identity" -o IdentitiesOnly=yes -o BatchMode=yes
  -o "HostKeyAlias=libvirt-$vm_create_uuid" -o "UserKnownHostsFile=$vm_create_cache/known_hosts"
  -o ConnectTimeout=3 -o ConnectionAttempts=1)
get_ip() {
  local interfaces
  interfaces=$(v domifaddr "$vm_create_name" --source agent 2>/dev/null) ||
    interfaces=$(v domifaddr "$vm_create_name" --source lease) || return 1
  vm_create_ip=$(awk '$3 == "ipv4" && $4 !~ /^127\./ {sub(/\/.*/, "", $4); print $4; exit}' <<<"$interfaces")
  [[ -n $vm_create_ip ]]
}
ssh_check() { timeout 8 "${vm_create_ssh[@]}" "$@"; }
# Fail immediately on the installer lifecycle regression rather than waiting
# two minutes to discover that the operator's first reboot switched the VM off.
vm_create_xml=$(v dumpxml "$vm_create_name")
vm_create_policy=$(xmllint --xpath 'string(/domain/on_reboot)' - <<<"$vm_create_xml")
vm_create_desktop=$(xmllint --xpath 'boolean(/domain/devices/graphics[@type="spice"])' - <<<"$vm_create_xml")
[[ $vm_create_policy == restart ]] || {
  printf 'FAIL: live reboot policy is %s; expected restart\n' "$vm_create_policy" >&2
  exit 1
}
get_ip
# Evaluate id in the guest shell.
# shellcheck disable=SC2016
ssh_check "root@$vm_create_ip" 'test "$(id -u)" = 0; systemctl is-active --quiet ssh qemu-guest-agent'
vm_create_work=$(mktemp -d)
trap 'rm -rf -- "$vm_create_work"' EXIT
if [[ -n $vm_create_denied_source ]]; then
  if ssh_check -b "$vm_create_denied_source" "root@$vm_create_ip" true 2>"$vm_create_work/denied"; then
    printf 'FAIL: SSH from a disallowed source reached the guest\n' >&2
    exit 1
  fi
  grep -qi 'timed out' "$vm_create_work/denied"
fi
if ssh_check -o PubkeyAuthentication=no -o PreferredAuthentications=password \
  "root@$vm_create_ip" true 2>"$vm_create_work/password"; then
  printf 'FAIL: password-only SSH succeeded\n' >&2
  exit 1
fi
grep -q 'Permission denied (publickey)' "$vm_create_work/password"
vm_create_before=$(ssh_check "root@$vm_create_ip" cat /proc/sys/kernel/random/boot_id)
desktop_ready() {
  [[ $vm_create_desktop == true ]] || return 0
  # Read the actual user's GNOME session bus, not just GDM's service status.
  # shellcheck disable=SC2016
  ssh_check "$vm_create_user@$vm_create_ip" '
    set -eu
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.GetNameOwner org.gnome.Shell >/dev/null
    test "$(gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \
      --method org.gnome.ScreenSaver.GetActive)" = "(false,)"
    test "$(gsettings get org.gnome.desktop.screensaver lock-enabled)" = false
  '
}
desktop_ready
v reboot "$vm_create_name"
vm_create_deadline=$((SECONDS + 120))
while :; do
  if get_ip && vm_create_after=$(ssh_check "root@$vm_create_ip" cat /proc/sys/kernel/random/boot_id 2>/dev/null) &&
     [[ $vm_create_after != "$vm_create_before" ]] && desktop_ready 2>/dev/null; then break; fi
  ((SECONDS < vm_create_deadline)) || { printf 'FAIL: guest did not return after reboot\n' >&2; exit 1; }
  sleep 2
done
# shellcheck disable=SC2016
ssh_check "$vm_create_user@$vm_create_ip" 'test "$(sudo -n id -u)" = 0'
ssh_check "root@$vm_create_ip" 'systemctl is-active --quiet ssh qemu-guest-agent; LC_ALL=C ufw status | grep -qx "Status: active"'
v qemu-agent-command "$vm_create_name" --timeout 5 '{"execute":"guest-ping"}'
printf 'PASS: reboot preserved user/root key access, sudo, services and guest-agent communication\n'
if [[ $vm_create_desktop == true ]]; then printf 'PASS: GNOME returned with automatic login and an unlocked desktop\n'; fi
