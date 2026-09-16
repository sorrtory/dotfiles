# Bootstrapping the staging VM over SSH

The staging VM (`Lubuntu24.04` in libvirt, `z@192.168.122.214`) proves the
fresh-machine flow: every bootstrap phase in order, from a snapshot with no
Nix. This is the procedure used from the host, including the parts that only
exist because the session has no terminal. For mirroring the working tree and
what the VM cannot verify, see [AGENTS.md](../AGENTS.md#staging).

## 1. Reset the VM

Revert to the `ssh-server` snapshot (SSH enabled, no Nix), then grow the disk.
Revert first: an internal qcow2 snapshot restores the disk size it was taken
with, so a resize made before reverting is undone.

```bash
virsh -c qemu:///system snapshot-revert Lubuntu24.04 ssh-server
virsh -c qemu:///system blockresize Lubuntu24.04 vda 40G
```

The snapshot's 15 GiB disk cannot hold the full environment: the staging
closure alone is about 10 GiB, on top of Ubuntu and the build itself. Then grow
the partition and filesystem inside the guest (step 2 provides sudo):

```bash
sudo -A env DEBIAN_FRONTEND=noninteractive apt-get install -y cloud-guest-utils
sudo -A growpart /dev/vda 1
sudo -A resize2fs /dev/vda1
```

`virsh` against `qemu:///system` works from the operator's account without
sudo. Write `virsh -c qemu:///system` out in full: zsh does not word-split an
unquoted variable holding the command.

A revert also restores the clock the snapshot was taken with, and `apt` rejects
repository metadata that is not valid yet, so `host-deps` fails on a snapshot
older than a day with `Release file ... is not valid yet`. `timedatectl set-ntp`
reports the clock as synchronized without stepping it, and the image has no
`hwclock`, so set it from the host before the first phase:

```bash
now=$(date -u '+%Y-%m-%d %H:%M:%S')
ssh z@192.168.122.214 "SUDO_ASKPASS=\$HOME/.staging-askpass /usr/bin/sudo -A date -u -s '$now'"
```

## 2. Allow sudo without a terminal (VM only)

Non-interactive `ssh` has no TTY, so phases that call `sudo` cannot prompt.
Plain `sudo` ignores `SUDO_ASKPASS` unless given `-A`, so put a wrapper first
on `PATH` for bootstrap runs. This stores the disposable VM's password in its
home directory; never do this on a real machine.

```bash
ssh z@192.168.122.214 '
  printf "#!/bin/sh\necho z\n" > ~/.staging-askpass && chmod 700 ~/.staging-askpass
  mkdir -p ~/.staging-bin
  printf "#!/bin/sh\nexec /usr/bin/sudo -A \"\$@\"\n" > ~/.staging-bin/sudo
  chmod 700 ~/.staging-bin/sudo'
```

Prefix bootstrap commands with
`SUDO_ASKPASS=$HOME/.staging-askpass PATH=$HOME/.staging-bin:$PATH`.

## 3. Send the tree

Create `~/Documents/dotfiles` on the guest, then use the rsync command from
AGENTS.md.

## 4. Unattended phases

```bash
ssh z@192.168.122.214 'cd ~/Documents/dotfiles &&
  SUDO_ASKPASS=$HOME/.staging-askpass PATH=$HOME/.staging-bin:$PATH \
  ./scripts/bootstrap.sh install host-deps nix'
```

## 5. Secret recovery (the operator)

This phase needs a GitHub sign-in and the KeePassXC vault password, so the
operator runs it with a terminal and approves the printed sign-in code on the
host:

```bash
ssh -t z@192.168.122.214 'cd ~/Documents/dotfiles && ./scripts/bootstrap.sh install secret-recovery'
```

## 6. Everything else, as staging

The VM runs alongside the host, so it must use the `staging` configuration and
its own VPN identity. The home-manager phase remembers the choice, so the
variable is only required on this first run:

```bash
ssh z@192.168.122.214 'cd ~/Documents/dotfiles &&
  export DOTFILES_HOME_CONFIGURATION=staging &&
  SUDO_ASKPASS=$HOME/.staging-askpass PATH=$HOME/.staging-bin:$PATH \
  ./scripts/bootstrap.sh install'
```

This runs the remaining phases in order, skipping satisfied ones, including
`apparmor`, which the VM needs because Ubuntu restricts unprivileged user
namespaces, and `virtualization`, which installs a host virtualization stack
inside the staging VM. KVM acceleration there requires nested virtualization
from the outer host.

### Virtualization verification

The `virtualization` phase can be tested independently of Nix and secret
recovery after mirroring the tree and preparing the sudo helper:

```bash
ssh z@192.168.122.214 'cd ~/Documents/dotfiles &&
  SUDO_ASKPASS=$HOME/.staging-askpass PATH=$HOME/.staging-bin:$PATH \
  ./scripts/bootstrap.sh install virtualization'
ssh z@192.168.122.214 'cd ~/Documents/dotfiles &&
  ./scripts/bootstrap.sh status virtualization &&
  virt-host-validate qemu &&
  virsh --readonly --connect qemu:///system net-info default'
```

Repeat installation to check that a configured machine reports
`already satisfied; skipping`. Use a fresh login before checking write access
through `virsh` or virt-manager after a group change.

Verified on 2026-09-16 against the Ubuntu 24.04.3 staging VM:

- Distro package installation completed. Ubuntu's `qemu-kvm` virtual package
  resolves to `qemu-system-x86`, which the phase checks directly.
- Status succeeded without sudo; repeat installation skipped without changes.
- The default network was active with autostart. Ubuntu's package setup detected
  the outer network's `192.168.122.0/24` subnet and selected `192.168.123.0/24`.
- `virt-host-validate qemu` passed hardware virtualization and KVM-device access.
  It warned about the devices cgroup controller, IOMMU and secure-guest support.
- A transient, diskless domain with `type='kvm'`, 128 MiB RAM, one vCPU and a
  virtio interface on the default network reached `running`, under AppArmor
  enforcement. The test domain was destroyed afterward.

This verifies installation and accelerated guest startup, not guest-OS boot,
guest internet access, PCI passthrough or the virt-manager desktop workflow.
The GUI still needs a normal-use check. Debian, Fedora, Arch and the modular
daemon layout are covered by `tests/bootstrap_virtualization_test.sh` using
command stubs, and have not been installed on real test machines.

On distros that do not resolve overlapping subnets automatically, adjust the
default network before retrying; the phase does not replace an existing network
definition. A missing `/dev/kvm` produces a warning even when installation and
service checks succeed, so a successful phase alone does not prove acceleration.

## 7. Clean up

Remove the sudo helpers once testing is done:

```bash
ssh z@192.168.122.214 'rm -rf ~/.staging-askpass ~/.staging-bin'
```

## Known issues

None tracked for recovery.
