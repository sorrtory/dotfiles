#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
export LC_ALL=C

usage() {
  cat <<'EOF'
Usage: vm-create NAME [OPTIONS]

Create a fresh Ubuntu 24.04 VM, install your server public key for the
guest user and root, and wait until first-boot provisioning is verified.
Run as your ordinary user; the host's libvirt daemon manages storage.

  --desktop            Install Ubuntu GNOME with automatic user login
  --view               Open the graphical console when ready (implies --desktop)
  --cpus N             Virtual CPUs (default: 2; desktop: 4)
  --ram MIB            Memory in MiB (default: 2048; desktop: 4096)
  --disk SIZE          Independent disk size (default: 20G; desktop: 40G)
  --user USER          Guest user with passwordless sudo (default: host user)
  --ssh-key FILE       Public keys (default: ~/.ssh/id_ed25519_servers.pub)
  --identity FILE      Matching private key used locally for verification
                       (default: ~/.config/sops-nix/secrets/id_ed25519_servers)
  --network NAME       Active IPv4 NAT network (default: default)
  --pool NAME          Active directory storage pool (default: default)
  --upgrade            Also upgrade all guest packages on first boot
  --autostart          Start this VM on subsequent host boots
  --ssh                Open an interactive user SSH session after verification
  --refresh-image      Select the latest released Ubuntu 24.04 cloud image
  --timeout SECONDS    Readiness deadline (default: 1800; desktop: 3600)
  -h, --help           Show this help

Examples:
  vm-create dev-server
  vm-create build-server --cpus 4 --ram 4096 --disk 40G
  vm-create persistent-server --upgrade --autostart
  vm-create interactive-server --ssh
  vm-create desktop-test --desktop --view
  vm-create larger-desktop --desktop --ram 8192 --disk 60G
  vm-create custom-key --ssh-key ~/.ssh/id_ed25519.pub \
    --identity ~/.ssh/id_ed25519

Passwords remain locked. Incoming SSH is allowed only from the NAT gateway
(the host). Desktop mode disables idle locking and suspension and uses a local
SPICE console. --view uses virt-viewer or virt-manager in a graphical host
session. Existing domains and disks are never overwritten. A VM whose
provisioning fails remains available for inspection; it is never repaired.
EOF
}

log() { printf 'vm-create: %s\n' "$*"; }
die() { printf 'vm-create: %s\n' "$*" >&2; exit 1; }
usage_error() { printf 'vm-create: %s\n' "$*" >&2; exit 2; }
need() { command -v "$1" >/dev/null || die "Missing command: $1"; }
v() { timeout 30 virsh --connect qemu:///system "$@"; }
contains() { grep -Fxq -- "$1" <<<"$2"; }

VM_NAME=''
VM_USER=$(id -un)
CPUS='' RAM='' DISK='' READY_TIMEOUT='' NETWORK=default POOL=default
PUBLIC_KEY="$HOME/.ssh/id_ed25519_servers.pub"
IDENTITY="$HOME/.config/sops-nix/secrets/id_ed25519_servers"
UPGRADE=false AUTOSTART=false OPEN_SSH=false REFRESH_IMAGE=false DESKTOP=false OPEN_VIEW=false
while (($#)); do
  case $1 in
    -h|--help) usage; exit 0 ;;
    --upgrade) UPGRADE=true; shift ;;
    --autostart) AUTOSTART=true; shift ;;
    --ssh) OPEN_SSH=true; shift ;;
    --desktop) DESKTOP=true; shift ;;
    --view) DESKTOP=true; OPEN_VIEW=true; shift ;;
    --refresh-image) REFRESH_IMAGE=true; shift ;;
    --cpus|--ram|--disk|--user|--ssh-key|--identity|--network|--pool|--timeout)
      (($# >= 2)) && [[ -n $2 ]] || usage_error "$1 needs a value"
      case $1 in
        --cpus) CPUS=$2 ;; --ram) RAM=$2 ;; --disk) DISK=$2 ;;
        --user) VM_USER=$2 ;; --ssh-key) PUBLIC_KEY=$2 ;; --identity) IDENTITY=$2 ;;
        --network) NETWORK=$2 ;; --pool) POOL=$2 ;; --timeout) READY_TIMEOUT=$2 ;;
      esac
      shift 2 ;;
    -*) usage_error "Unknown option: $1" ;;
    *) [[ -z $VM_NAME ]] || usage_error 'Provide exactly one VM name'; VM_NAME=$1; shift ;;
  esac
done
if [[ $DESKTOP == true ]]; then
  CPUS=${CPUS:-4} RAM=${RAM:-4096} DISK=${DISK:-40G} READY_TIMEOUT=${READY_TIMEOUT:-3600}
else
  CPUS=${CPUS:-2} RAM=${RAM:-2048} DISK=${DISK:-20G} READY_TIMEOUT=${READY_TIMEOUT:-1800}
fi
[[ $VM_NAME =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] ||
  usage_error 'NAME must be a lowercase hostname of 1–63 letters, digits or hyphens'
[[ $VM_USER =~ ^[a-z_][a-z0-9_-]{0,31}$ && $VM_USER != root ]] || usage_error 'Invalid guest user'
if ! [[ $CPUS =~ ^[1-9][0-9]{0,3}$ ]] || ((CPUS > 1024)); then usage_error 'Invalid CPU count'; fi
if ! [[ $RAM =~ ^[1-9][0-9]{0,6}$ ]] || ((RAM < 128 || RAM > 1048576)); then usage_error 'Invalid RAM size'; fi
[[ $DISK =~ ^[1-9][0-9]{0,5}[MGT]$ ]] || usage_error 'Disk size must be a positive integer followed by M, G or T'
if ! [[ $READY_TIMEOUT =~ ^[1-9][0-9]{0,4}$ ]] || ((READY_TIMEOUT > 86400)); then usage_error 'Invalid timeout'; fi
for name in "$NETWORK" "$POOL"; do
  [[ $name =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,62}$ ]] || usage_error 'Invalid network or pool name'
done
((EUID != 0)) || die 'Run as your ordinary user, without sudo'
[[ $(uname -m) == x86_64 ]] || die 'This Ubuntu image requires an x86_64 host'
for cmd in virsh virt-install qemu-img curl jq xmllint ssh ssh-keygen ssh-add flock timeout \
           sha256sum numfmt awk grep mktemp mkdir mv rm stat cp cat date sleep; do need "$cmd"; done
VIEWER=()
if [[ $DESKTOP == true ]]; then
  if command -v virt-viewer >/dev/null; then
    VIEWER=(virt-viewer --connect qemu:///system "$VM_NAME")
  else
    VIEWER=(virt-manager --connect qemu:///system --show-domain-console "$VM_NAME")
  fi
fi
if [[ $OPEN_VIEW == true ]]; then
  [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || die '--view requires a graphical host session; use --desktop and open the console later'
  need "${VIEWER[0]}"
fi
DISK_BYTES=$(numfmt --from=iec "$DISK")
((DISK_BYTES <= 17592186044416)) || usage_error 'Disk size exceeds 16 TiB'
[[ -r $PUBLIC_KEY && -r $IDENTITY ]] || die 'The public key and matching private identity must be readable'

WORK_DIR=$(mktemp -d)
DISK_VOLUME="$VM_NAME.qcow2"
DISK_CREATED=false BASE_CREATED=false BASE_READY=false SUCCESS=false
BASE_VOLUME=''
cleanup() {
  local status=$?
  trap - EXIT
  # Once a domain exists, even a partially defined one, keep its disk. An
  # unavailable libvirt connection is also a reason to preserve the disk.
  if [[ $DISK_CREATED == true && $SUCCESS == false ]]; then
    local domains
    if domains=$(v list --all --name) && ! contains "$VM_NAME" "$domains"; then
      v vol-delete "$DISK_VOLUME" --pool "$POOL" >/dev/null || true
    else
      printf 'vm-create: VM and disk preserved. Inspect: virsh -c qemu:///system console %q\n' "$VM_NAME" >&2
    fi
  fi
  if [[ $BASE_CREATED == true && $BASE_READY == false ]]; then
    v vol-delete "$BASE_VOLUME" --pool "$POOL" >/dev/null || true
  fi
  rm -rf -- "$WORK_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Normalize public keys only; a private key never enters cloud-init or storage.
awk '$1 ~ /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))$/ &&
     $2 ~ /^[A-Za-z0-9+\/=]+$/ && !seen[$1 " " $2]++ {print $1 " " $2}' \
  "$PUBLIC_KEY" >"$WORK_DIR/keys.pub"
[[ -s $WORK_DIR/keys.pub ]] || die 'No supported public keys found'
while IFS= read -r key; do
  ssh-keygen -lf /dev/stdin <<<"$key" >>"$WORK_DIR/fingerprints" || die 'Invalid public key'
done <"$WORK_DIR/keys.pub"
FINGERPRINT=$(ssh-keygen -lf "$IDENTITY" | awk '{print $2}') || die 'Invalid private identity'
awk -v key="$FINGERPRINT" '$2 == key {found=1} END {exit !found}' "$WORK_DIR/fingerprints" ||
  die 'The private identity does not match any supplied public key'
if ! ssh-keygen -y -P '' -f "$IDENTITY" >/dev/null 2>&1; then
  ssh-add -l | awk -v key="$FINGERPRINT" '$2 == key {found=1} END {exit !found}' ||
    die 'Encrypted identity is not in ssh-agent; load it with ssh-add before creating a VM'
fi

log 'Checking libvirt, network and storage...'
v uri >/dev/null || die 'Cannot connect to qemu:///system; run the virtualization bootstrap phase first'
DOMAINS=$(v list --all --name)
contains "$VM_NAME" "$DOMAINS" && die "VM '$VM_NAME' already exists"
NETWORKS=$(v net-list --name)
contains "$NETWORK" "$NETWORKS" || die "Network '$NETWORK' must already be active"
v net-dumpxml "$NETWORK" >"$WORK_DIR/network.xml"
[[ $(xmllint --xpath 'string(/network/forward/@mode)' "$WORK_DIR/network.xml") == nat ]] || die 'An IPv4 NAT network is required'
GATEWAY=$(xmllint --xpath 'string(/network/ip[not(@family) or @family="ipv4"][1]/@address)' "$WORK_DIR/network.xml")
[[ $GATEWAY =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die 'The network has no IPv4 gateway'
[[ $(xmllint --xpath 'count(/network/ip[not(@family) or @family="ipv4"][1]/dhcp/range)' "$WORK_DIR/network.xml") != 0 ]] ||
  die 'The NAT network requires an IPv4 DHCP range'
POOLS=$(v pool-list --name)
contains "$POOL" "$POOLS" || die "Storage pool '$POOL' must already be active; create it in virt-manager or use --pool"
v pool-dumpxml "$POOL" >"$WORK_DIR/pool.xml"
[[ $(xmllint --xpath 'string(/pool/@type)' "$WORK_DIR/pool.xml") == dir ]] || die 'A directory storage pool is required'
VOLUMES=$(v vol-list "$POOL" | awk 'NR > 2 && NF {print $1}')
contains "$DISK_VOLUME" "$VOLUMES" && die "Disk '$DISK_VOLUME' already exists in pool '$POOL'"
OSINFO_LIST=$(virt-install --osinfo list)
VM_OSINFO=generic
if grep -Eq '(^|[[:space:],])ubuntu24\.04([[:space:],]|$)' <<<"$OSINFO_LIST"; then VM_OSINFO=ubuntu24.04; fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vm-create"
mkdir -p -- "$CACHE_DIR"
# One invocation per user keeps downloads, seed preparation and creation from
# racing. libvirt independently refuses duplicate volume and domain names.
exec 9>"$CACHE_DIR/lock"
flock -n 9 || die 'Another vm-create is running'
SOURCE_ROOT=https://cloud-images.ubuntu.com
CURL=(curl --fail --location --show-error --silent --retry 3 --connect-timeout 15)
[[ -z ${PROXY:-} ]] || CURL+=(--proxy "$PROXY")
if [[ ! -f $CACHE_DIR/image.json || $REFRESH_IMAGE == true ]]; then
  log 'Selecting the latest released Ubuntu 24.04 image...'
  "${CURL[@]}" --max-time 120 -o "$WORK_DIR/releases.json" \
    "$SOURCE_ROOT/releases/streams/v1/com.ubuntu.cloud:released:download.json"
  jq -e '.products["com.ubuntu.cloud:server:24.04:amd64"].versions |
         to_entries | max_by(.key) | .value.items["disk1.img"] |
         {path, sha256, size}' "$WORK_DIR/releases.json" >"$WORK_DIR/image.json"
else
  cp -- "$CACHE_DIR/image.json" "$WORK_DIR/image.json"
fi
IMAGE_PATH=$(jq -er '.path' "$WORK_DIR/image.json")
IMAGE_HASH=$(jq -er '.sha256' "$WORK_DIR/image.json")
IMAGE_SIZE=$(jq -er '.size' "$WORK_DIR/image.json")
[[ $IMAGE_PATH =~ ^server/releases/noble/release-[0-9]+/ubuntu-24\.04-server-cloudimg-amd64\.img$ &&
   $IMAGE_HASH =~ ^[a-f0-9]{64}$ && $IMAGE_SIZE =~ ^[1-9][0-9]{0,10}$ ]] || die 'Invalid Ubuntu release metadata'
cp -- "$WORK_DIR/image.json" "$CACHE_DIR/image.json.tmp"
mv -- "$CACHE_DIR/image.json.tmp" "$CACHE_DIR/image.json"
BASE_IMAGE="$CACHE_DIR/$IMAGE_HASH.img"
PART_IMAGE="$BASE_IMAGE.part"
if [[ ! -f $BASE_IMAGE ]]; then
  log 'Downloading Ubuntu (interrupted downloads resume)...'
  "${CURL[@]}" --no-silent --progress-bar --continue-at - -o "$PART_IMAGE" "$SOURCE_ROOT/$IMAGE_PATH" ||
    die 'Download failed; partial image retained for the next run'
  if ! printf '%s  %s\n' "$IMAGE_HASH" "$PART_IMAGE" | sha256sum --check --status; then
    rm -f -- "$PART_IMAGE"
    die 'Downloaded image failed SHA-256 verification; invalid partial removed'
  fi
  mv -- "$PART_IMAGE" "$BASE_IMAGE"
fi
printf '%s  %s\n' "$IMAGE_HASH" "$BASE_IMAGE" | sha256sum --check --status || die 'Cached image failed SHA-256 verification'
[[ $(stat -c %s "$BASE_IMAGE") == "$IMAGE_SIZE" ]] || die 'Image size does not match Ubuntu metadata'
qemu-img info --output=json "$BASE_IMAGE" >"$WORK_DIR/image-info.json"
jq -e '.format == "qcow2" and (."backing-filename" // "") == ""' "$WORK_DIR/image-info.json" >/dev/null ||
  die 'Expected a standalone QCOW2 cloud image'
BASE_CAPACITY=$(jq -er '."virtual-size"' "$WORK_DIR/image-info.json")
((DISK_BYTES >= BASE_CAPACITY)) || die 'Requested disk would shrink the cloud image'

BASE_VOLUME="vm-create-ubuntu-24.04-$IMAGE_HASH.img"
VOLUMES=$(v vol-list "$POOL" | awk 'NR > 2 && NF {print $1}')
if contains "$BASE_VOLUME" "$VOLUMES"; then
  log 'Verifying the cached libvirt base image...'
  v vol-download "$BASE_VOLUME" "$WORK_DIR/base.img" --pool "$POOL" --length "$IMAGE_SIZE"
  printf '%s  %s\n' "$IMAGE_HASH" "$WORK_DIR/base.img" | sha256sum --check --status || die 'Libvirt base image failed SHA-256 verification'
else
  log 'Uploading the verified base image to libvirt storage...'
  v vol-create-as "$POOL" "$BASE_VOLUME" "$BASE_CAPACITY" --format qcow2 >/dev/null
  BASE_CREATED=true
  v vol-upload "$BASE_VOLUME" "$BASE_IMAGE" --pool "$POOL" --sparse
fi
BASE_READY=true
cat >"$WORK_DIR/disk.xml" <<EOF
<volume><name>$DISK_VOLUME</name><capacity unit="bytes">$BASE_CAPACITY</capacity>
<allocation>0</allocation><target><format type="qcow2"/></target></volume>
EOF
log 'Creating an independent VM disk...'
v vol-create-from "$POOL" "$WORK_DIR/disk.xml" "$BASE_VOLUME" --inputpool "$POOL" >/dev/null
DISK_CREATED=true
v vol-resize "$DISK_VOLUME" "$DISK_BYTES" --pool "$POOL" >/dev/null
VM_DISK=$(v vol-path "$DISK_VOLUME" --pool "$POOL")
KEYS_YAML=$(awk '{printf "      - \"%s\"\n", $0}' "$WORK_DIR/keys.pub")
PACKAGES='openssh-server, curl, wget, git, vim, htop, qemu-guest-agent, ufw'
if [[ $DESKTOP == true ]]; then PACKAGES+=', ubuntu-desktop-minimal, spice-vdagent'; fi
cat >"$WORK_DIR/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
disable_root: false
ssh_pwauth: false
users:
  - name: $VM_USER
    shell: /bin/bash
    groups: [sudo]
    sudo: "ALL=(ALL) NOPASSWD:ALL"
    lock_passwd: true
    ssh_authorized_keys:
$KEYS_YAML
  - name: root
    lock_passwd: true
    ssh_authorized_keys:
$KEYS_YAML
package_update: true
package_upgrade: $UPGRADE
packages: [$PACKAGES]
write_files:
  - path: /etc/ssh/sshd_config.d/01-vm-create.conf
    permissions: "0644"
    content: |
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin prohibit-password
      AllowUsers $VM_USER root
EOF
if [[ $DESKTOP == true ]]; then
  # ubuntu-settings changes Netplan's default renderer during package install.
  # Keep the existing DHCP connection until the final cold boot, when the
  # installed desktop can safely take over through NetworkManager.
  cat >>"$WORK_DIR/user-data" <<'EOF'
  - path: /etc/netplan/99-vm-create-first-boot.yaml
    permissions: "0600"
    content: |
      network:
        version: 2
        renderer: networkd
EOF
  # Defer desktop files until packages/users exist, before the first desktop
  # session. GDM autologin works without unlocking either account's password.
  cat >>"$WORK_DIR/user-data" <<EOF
  - path: /etc/gdm3/custom.conf
    permissions: "0644"
    defer: true
    content: |
      [daemon]
      AutomaticLoginEnable=True
      AutomaticLogin=$VM_USER
  - path: /etc/dconf/profile/user
    permissions: "0644"
    defer: true
    content: |
      user-db:user
      system-db:local
  - path: /etc/dconf/db/local.d/00-vm-create
    permissions: "0644"
    defer: true
    content: |
      [org/gnome/desktop/lockdown]
      disable-lock-screen=true
      [org/gnome/desktop/screensaver]
      lock-enabled=false
      [org/gnome/desktop/session]
      idle-delay=uint32 0
      [org/gnome/settings-daemon/plugins/power]
      sleep-inactive-ac-type='nothing'
      sleep-inactive-battery-type='nothing'
  - path: /home/$VM_USER/.config/gnome-initial-setup-done
    owner: $VM_USER:$VM_USER
    permissions: "0644"
    defer: true
    content: "yes"
  - path: /home/$VM_USER/.config/autostart/update-notifier.desktop
    owner: $VM_USER:$VM_USER
    permissions: "0644"
    defer: true
    content: |
      [Desktop Entry]
      Type=Application
      Name=Update Notifier
      Hidden=true
EOF
fi
cat >>"$WORK_DIR/user-data" <<EOF
runcmd:
  - [systemctl, enable, --now, ssh]
  - [systemctl, restart, ssh]
  - [systemctl, enable, --now, qemu-guest-agent]
  - [ufw, default, deny, incoming]
  - [ufw, default, allow, outgoing]
  - [ufw, allow, from, "$GATEWAY", to, any, port, "22", proto, tcp]
  - [ufw, --force, enable]
EOF
if [[ $DESKTOP == true ]]; then
  cat >>"$WORK_DIR/user-data" <<EOF
  - [chown, -R, "$VM_USER:$VM_USER", "/home/$VM_USER/.config"]
  - [rm, /etc/netplan/99-vm-create-first-boot.yaml]
  - [systemctl, disable, systemd-networkd-wait-online.service]
  - [dconf, update]
  - [systemctl, set-default, graphical.target]
  - [systemctl, restart, gdm3]
EOF
fi
cat >>"$WORK_DIR/user-data" <<'EOF'
growpart:
  mode: auto
  devices: ["/"]
resize_rootfs: true
EOF
printf 'instance-id: %s\nlocal-hostname: %s\n' "$VM_NAME-$(date +%s)-$$" "$VM_NAME" >"$WORK_DIR/meta-data"
DISPLAY_OPTIONS=(--graphics none)
if [[ $DESKTOP == true ]]; then
  DISPLAY_OPTIONS=(--graphics 'spice,listen=none' --video virtio --input 'tablet,bus=usb'
    --channel spicevmc --sound ich9)
fi
log "Starting $VM_NAME..."
virt-install --connect qemu:///system --name "$VM_NAME" --memory "$RAM" --vcpus "$CPUS" \
  --osinfo "$VM_OSINFO" --import --disk "vol=$POOL/$DISK_VOLUME,format=qcow2,bus=virtio" \
  --cloud-init "user-data=$WORK_DIR/user-data,meta-data=$WORK_DIR/meta-data" \
  --network "network=$NETWORK,model=virtio" \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
  "${DISPLAY_OPTIONS[@]}" --console pty,target_type=serial --noautoconsole

DEADLINE=$((SECONDS + READY_TIMEOUT))
wait_for() {
  local description=$1
  shift
  log "Waiting for $description..."
  until "$@" >"$WORK_DIR/probe-output" 2>"$WORK_DIR/probe-error"; do
    if ((SECONDS >= DEADLINE)); then
      cat "$WORK_DIR/probe-output" "$WORK_DIR/probe-error" >&2
      die "Timed out waiting for $description"
    fi
    sleep 2
  done
}
VM_IP=''
get_ip() {
  local interfaces
  interfaces=$(v domifaddr "$VM_NAME" --source agent 2>/dev/null) ||
    interfaces=$(v domifaddr "$VM_NAME" --source lease) || return 1
  VM_IP=$(awk '$3 == "ipv4" && $4 !~ /^127\./ {sub(/\/.*/, "", $4); print $4; exit}' <<<"$interfaces")
  [[ $VM_IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}
wait_for 'a DHCP address' get_ip
UUID=$(v domuuid "$VM_NAME")
SSH_CMD=(ssh -i "$IDENTITY" -o IdentitiesOnly=yes -o BatchMode=yes
  -o PreferredAuthentications=publickey -o PasswordAuthentication=no
  -o KbdInteractiveAuthentication=no -o StrictHostKeyChecking=accept-new
  -o "HostKeyAlias=libvirt-$UUID" -o "UserKnownHostsFile=$CACHE_DIR/known_hosts"
  -o ConnectTimeout=5 -o ConnectionAttempts=1 -o ServerAliveInterval=10 -o ServerAliveCountMax=3)
ssh_check() { timeout -k 2 15 "${SSH_CMD[@]}" -T -n "$@"; }
user_ssh_ready() { get_ip && ssh_check "$VM_USER@$VM_IP" true; }
wait_for 'user SSH key authentication' user_ssh_ready
log 'Waiting for cloud-init to finish...'
REMAINING=$((DEADLINE - SECONDS))
((REMAINING > 0)) || die 'Readiness deadline reached before cloud-init completed'
timeout -k 5 "$REMAINING" "${SSH_CMD[@]}" -T -n "$VM_USER@$VM_IP" \
  'sudo -n cloud-init status --wait --long' || die 'cloud-init failed or exceeded the readiness deadline'
# virt-install starts cloud-init with temporary media and on_reboot=destroy,
# then defines the final persistent XML separately. A graceful cold restart
# switches to that final XML; otherwise the operator's first reboot stops the
# VM. Do this before reporting readiness and verify the final boot below.
log 'Completing the cloud-init first-boot lifecycle...'
v shutdown "$VM_NAME" >/dev/null
domain_stopped() {
  local state
  state=$(v domstate "$VM_NAME") || return 1
  [[ $state == 'shut off' ]]
}
wait_for 'first-boot shutdown' domain_stopped
v start "$VM_NAME" >/dev/null
wait_for 'the final boot address' get_ip
wait_for 'user SSH after the final boot' user_ssh_ready
ssh_check "$VM_USER@$VM_IP" "test \"\$(id -un)\" = '$VM_USER' && test \"\$(sudo -n id -u)\" = 0" || die 'User SSH or passwordless sudo failed'
ROOT_CHECK=$(cat <<'EOF'
set -eu
test "$(id -u)" = 0
systemctl is-active --quiet ssh
systemctl is-active --quiet qemu-guest-agent
test "$(passwd -S root | awk '{print $2}')" = L
test "$(passwd -S "$VM_USER" | awk '{print $2}')" = L
sshd -T | grep -qx 'passwordauthentication no'
sshd -T | grep -qx 'kbdinteractiveauthentication no'
firewall=$(LC_ALL=C ufw status verbose)
grep -qx 'Status: active' <<END
$firewall
END
grep -q '^Default: deny (incoming), allow (outgoing)' <<END
$firewall
END
awk -v host="$HOST_IP" '$2 == "ALLOW" && $3 == "IN" {
  rules++; if ($1 != "22/tcp" || $4 != host) invalid=1
} END {exit invalid || rules != 1}' <<END
$firewall
END
EOF
)
ssh_check "root@$VM_IP" "VM_USER=$VM_USER; HOST_IP=$GATEWAY; $ROOT_CHECK" || die 'Root SSH, services, locked passwords or host-only firewall verification failed'
wait_for 'guest-agent communication' v qemu-agent-command "$VM_NAME" --timeout 5 '{"execute":"guest-ping"}'
if [[ $DESKTOP == true ]]; then
  DESKTOP_CHECK=$(cat <<'EOF'
set -eu
systemctl is-active --quiet gdm3
systemctl is-active --quiet NetworkManager
test "$(systemctl get-default)" = graphical.target
test "$(stat -c %U "$HOME/.config")" = "$(id -un)"
desktop_session=false
for session in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
  test "$(loginctl show-session "$session" --property=Name --value)" = "$(id -un)" || continue
  case $(loginctl show-session "$session" --property=Type --value) in
    x11|wayland) ;; *) continue ;;
  esac
  test "$(loginctl show-session "$session" --property=Active --value)" = yes || continue
  test "$(loginctl show-session "$session" --property=Remote --value)" = no || continue
  desktop_session=true
done
test "$desktop_session" = true
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
  --method org.freedesktop.DBus.GetNameOwner org.gnome.Shell
test "$(gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver \
  --method org.gnome.ScreenSaver.GetActive)" = '(false,)'
test "$(gsettings get org.gnome.desktop.screensaver lock-enabled)" = false
test "$(gsettings get org.gnome.desktop.lockdown disable-lock-screen)" = true
test "$(gsettings get org.gnome.desktop.session idle-delay)" = 'uint32 0'
test "$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)" = "'nothing'"
test "$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type)" = "'nothing'"
EOF
  )
  wait_for 'an unlocked GNOME desktop with automatic login' ssh_check "$VM_USER@$VM_IP" "$DESKTOP_CHECK"
fi
if [[ $AUTOSTART == true ]]; then v autostart "$VM_NAME" >/dev/null; fi
SUCCESS=true
printf '\nVM ready: %s (Ubuntu 24.04)\nIP: %s\nDisk: %s\n\nConnect with SSH by running:\n  ' "$VM_NAME" "$VM_IP" "$VM_DISK"
printf '%q ' "${SSH_CMD[@]}" "$VM_USER@$VM_IP"
printf '\n\nTo connect as root, run:\n  '
printf '%q ' "${SSH_CMD[@]}" "root@$VM_IP"
printf '\n'
if [[ $DESKTOP == true ]]; then
  printf '\nOpen the GNOME desktop by running:\n  '
  printf '%q ' "${VIEWER[@]}"
  printf '\n'
fi
# Do not let an interactive session retain the creation lock.
flock -u 9
if [[ $OPEN_VIEW == true ]]; then "${VIEWER[@]}"; fi
if [[ $OPEN_SSH == true ]]; then "${SSH_CMD[@]}" -tt "$VM_USER@$VM_IP"; fi
