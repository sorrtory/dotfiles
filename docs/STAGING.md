# Staging VM

A staging VM is a disposable machine used to check the fresh-machine flow and
anything that must not be tried first on the operator's own host. The working
tree on the host is always the source of truth; the VM mirrors it and never
syncs back.

## Current VM

`fedora` in libvirt, reachable at `z@192.168.122.21`. It runs **Fedora 44
Workstation** with 2 vCPUs, about 3.8 GiB of RAM and 14 GiB free on `/`. Its
session is GNOME on Wayland with gdm active, the same session type as the
operator's desktop, so GNOME work — dconf settings, launchers, Shell extensions,
session environment variables — can be judged here rather than only on the host.

Log in with the `id_ed25519_servers` key; `ssh-add
~/.config/sops-nix/secrets/id_ed25519_servers` first if the agent does not have
it. The login and `sudo` password is `z`, an intentionally public [staging
credential](../CONTEXT.md) that no trusted machine or service reuses.

Reset it rather than cleaning up by hand:

```bash
virsh -c qemu:///system snapshot-revert fedora 'fresh + ssh'
```

The snapshot is a fresh install with only the SSH server added: no Nix, no
mirrored tree, GNOME at its defaults.

### Bootstrap progress

Verified on 2026-09-20 from that snapshot, with the mirroring command and sudo
helper below:

- `host-repos` pinned Fedora and RPM Fusion to Yandex, disabled the Cisco
  OpenH264 repository, and reconciled the package set. **It took 109 minutes**
  on 2 vCPUs: a `distro-sync` plus two full upgrades against release-media
  packages is the dominant cost of a fresh bootstrap, and it is worth starting
  before doing something else.
- `host-deps` then found its CA bundle already in place, because that upgrade
  brought `ca-certificates` current as a side effect, and installed `zsh`.
- `nix` installed Fedora's `nix` 2.34.8 RPM, created the `nixbld` users and
  enabled `nix-daemon.service`. A login shell exports
  `NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`.
- `apparmor` reports `unprivileged user namespaces are not restricted; no
  profiles needed`, which is Fedora behaving as expected — that phase exists for
  Ubuntu.

The 109-minute run also settled the ordering question. A whole-system upgrade
fails outright on default mirrors, because Fedora Workstation enables Cisco's
`openh264` repository and this network cannot reach it. The same upgrade
succeeds once `host-repos` has pinned the mirrors and disabled that repository,
which is the argument for repository policy being phase 01.

`secret-recovery` is the next phase and is the operator's: it needs a GitHub
sign-in and the KeePassXC vault password, so it has to be run with a terminal.
Nothing past it has been exercised on Fedora yet.

This VM has already paid for itself. On the first run `secret-recovery`
authenticated to GitHub and then failed to clone:

```
fatal: unable to access 'https://github.com/sorrtory/keepass.git/':
SSL certificate OpenSSL verify result: unable to get local issuer certificate (20)
```

Fedora 44's release media ships a `ca-certificates` too old to own
`/etc/ssl/certs/ca-certificates.crt`, the first path Nix's profile script
probes, so `NIX_SSL_CERT_FILE` was never exported and the flake's Nixpkgs-built
`git` had no bundle — while `dnf`, `gh` and `/usr/bin/git` all worked, which is
what made it look like anything but a trust problem. `host-deps` now probes for
that bundle and refreshes the host packages it declares, so the fault is caught
two phases before it used to appear. The operator's own host never hit it: an
installed Fedora picks up the newer `ca-certificates` on its first update.

The VM also settled how broad that repair should be. A whole-system upgrade
inside `host-deps` fails, because that phase runs before any mirror is pinned
and Fedora Workstation enables Cisco's `openh264` repository, which this
network cannot reach:

```
Failed to download packages
 Librepo error: Cannot download Packages/o/openh264-2.6.0-3.fc44.x86_64.rpm: All mirrors were tried
```

`--skip-unavailable` does not cover a download failure. Refreshing the declared
packages instead completes in about 15 seconds from the same snapshot, and
works on a distribution that has no repository phase at all.

An earlier VM, `silverblue43`, ran Fedora 43 Silverblue and could not bootstrap
at all: `common/packages.sh` maps `ID=fedora` to `dnf`, which an rpm-ostree
image does not ship, and `02-nix` installs Nix onto a read-only `/`. It was
replaced by this Workstation VM rather than fixed. Supporting rpm-ostree remains
unstarted work with no effort opened.

## Mirroring the working tree

The guest copy is a plain directory, not a clone, so every edit, commit and Git
operation stays on the host. Run this from the repository root:

```bash
rsync -ai --delete \
  --exclude='.git/' --exclude='.scratch/' --exclude='result' --exclude='result-*' \
  ./ z@192.168.122.21:~/Documents/dotfiles/
```

`-a` preserves modes, timestamps and symlinks; `-i` reports exactly what
changed, which is what makes an unexpected transfer visible; `--delete` is what
makes the guest a mirror rather than a pile of leftovers. Repeat with `-n` first
whenever the delete list matters. Do not add `-z`: it is small text over a local
bridge.

Each exclusion is load-bearing. `.git/` keeps history on the host. `.scratch/`
is host-side coordination material. `result` and `result-*` point into the
guest's own `/nix/store` and cannot come from the host — without excluding them,
`--delete` removes the very symlink `./result/activate` needs. `--delete` never
removes an excluded path, so a stale excluded directory from an earlier sync has
to be deleted by hand.

## sudo without a terminal

Non-interactive `ssh` has no TTY, and plain `sudo` ignores `SUDO_ASKPASS`
without `-A`, so put a wrapper first on `PATH` for bootstrap runs. This writes
the disposable VM's password into its home directory; never do this on a real
machine.

```bash
ssh z@192.168.122.21 '
  printf "#!/bin/sh\necho z\n" > ~/.staging-askpass && chmod 700 ~/.staging-askpass
  mkdir -p ~/.staging-bin
  printf "#!/bin/sh\nexec /usr/bin/sudo -A \"\$@\"\n" > ~/.staging-bin/sudo
  chmod 700 ~/.staging-bin/sudo'
```

Prefix bootstrap commands with
`SUDO_ASKPASS=$HOME/.staging-askpass PATH=$HOME/.staging-bin:$PATH`, and remove
both helpers when testing is done.

Phases that need a real terminal are the operator's: `secret-recovery` wants a
GitHub sign-in and the KeePassXC vault password, so run it with `ssh -t`.

## What a VM cannot verify

The guest has no usable GPU, so anything reaching a real driver — the `nix-gpu`
phase, hardware decode, WezTerm opening a window — has to be judged on the host.

Settings a session only reads at login still need a real re-login, not a
reconnect: `environment.d`, newly installed GNOME extensions and XKB options.
This VM can give one, since its session is GNOME on Wayland like the host's.

A VM running alongside the host must use the `staging` configuration and its own
VPN identity. Never run the same identity in two places at once.

## Historical Ubuntu verification

These results were measured on Ubuntu VMs that no longer exist. They remain
valid records of what was checked on Ubuntu, and are not evidence about Fedora.

**Virtualization, 2026-09-16, Ubuntu 24.04.3:**

- Distro package installation completed. Ubuntu's `qemu-kvm` virtual package
  resolves to `qemu-system-x86`, which the phase checks directly.
- Status succeeded without sudo; repeat installation skipped without changes.
- The default network was active with autostart. Ubuntu's package setup detected
  the outer network's `192.168.122.0/24` subnet and selected `192.168.123.0/24`.
- `virt-host-validate qemu` passed hardware virtualization and KVM-device
  access. It warned about the devices cgroup controller, IOMMU and secure-guest
  support.
- A transient, diskless domain with `type='kvm'`, 128 MiB RAM, one vCPU and a
  virtio interface on the default network reached `running` under AppArmor
  enforcement, and was destroyed afterward.

That covers installation and accelerated guest startup, not guest-OS boot, guest
internet access, PCI passthrough or the virt-manager workflow. Debian, Fedora,
Arch and the modular daemon layout are covered only by
`tests/bootstrap_virtualization_test.sh` with command stubs. On distros that do
not resolve overlapping subnets automatically, adjust the default network before
retrying; the phase does not replace an existing network definition. A missing
`/dev/kvm` produces a warning even when installation and service checks succeed,
so a successful phase alone does not prove acceleration.

The slice records in [MIGRATION.md](MIGRATION.md) name the other Ubuntu staging
results: the VPN command, Neovim, tmux, Yazi and the local proxy.
