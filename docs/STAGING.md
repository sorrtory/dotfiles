# Staging VM

A staging VM is a disposable machine used to check the fresh-machine flow and
anything that must not be tried first on the operator's own host. The working
tree on the host is always the source of truth; the VM mirrors it and never
syncs back.

## Current VM

`fedora` in libvirt, reachable at `z@192.168.122.21`. Its guest hostname
is `fedora-staging` since 2026-09-23: the daily host is also `fedora`, and the
encrypted VPN policy needs distinct hostname keys for their independent peers.
A snapshot revert restores the old guest hostname; set it back to
`fedora-staging` before activating an inventory-based VPN generation. It runs
**Fedora 44 Workstation** with 2 vCPUs, about 3.8 GiB of RAM and a 30 GiB `/`. Its
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

The whole `bootstrap.sh install` chain is green on Fedora, verified 2026-09-20
from the `fresh + ssh` snapshot. The result is kept as the `bootstrapped`
snapshot, so it can be returned to without repeating the two-hour first phase:

```bash
virsh -c qemu:///system snapshot-revert fedora bootstrapped
```

Timings and the two things that needed intervention:

- `host-repos` took **109 minutes** on 2 vCPUs. A `distro-sync` plus two full
  upgrades against release-media packages is the dominant cost of a fresh
  bootstrap; start it before doing something else.
- `host-deps` then found its CA bundle already in place, because that upgrade
  brings `ca-certificates` current as a side effect, and installed `zsh`.
- `nix` installed Fedora's `nix` 2.34.8 RPM. A login shell exports
  `NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`.
- `secret-recovery` is the operator's: GitHub device flow plus the KeePassXC
  vault password, so it needs `ssh -t`.
- `home-manager` activated the `staging` generation in **8m21s**.
- `yt-dlp`, `docker`, `login-shell`, `user-linger` took 29 seconds together.
  `apparmor` correctly does nothing: Fedora does not restrict unprivileged user
  namespaces.
- `native-toolchain` and `nix-gpu` completed. `fedora-amd-gpu` correctly skips a
  machine with no AMD GPU, which is the split working as intended.

Afterwards `zsh` is the login shell, the Nix profile carries `rg`, `bat`, `fzf`,
`yazi`, `nvim`, `tmux`, `wezterm` and `vpn`, `convert-to`/`download`/`vault` are
in `~/.local/bin`, sing-box is active and linger is enabled.

The VM was rebuilt with a 30 GiB disk on 2026-09-23, which is what the note
below asks for; the two records under it are kept because the failure modes
they describe are what a too-small disk looks like.

**An 18 GiB disk is too small.** The activated closure took the guest to 92%
with 1.5 GiB free, before `virtualization` and `native-toolchain` had installed
anything. `nix-collect-garbage` recovered 1.9 GiB and the rest fit, but give a
new staging VM 30 GiB rather than repeating that.

By 2026-09-23 it no longer fit at all. Three days of pin drift left little of
the bootstrapped store shared with the new closure: after
`nix-collect-garbage -d` freed 1.6 GiB, `nix build --dry-run` wanted **13.4 GiB
unpacked** against 1.9 GiB free. A build attempted anyway dies as
`error: write of 65536 bytes: No space left on device`, and everything after it
is a cascade of `some references ... could not be realised`, which reads like a
substituter problem and is not one — check `df` first.

**A full disk deadlocks the collector.** At 0 bytes free `nix-collect-garbage`
cannot commit its own transaction and deletes nothing:

```
error: committing transaction: database or disk is full (in '/nix/var/nix/db/db.sqlite')
0 store paths deleted, 0.0 KiB freed
```

Free something outside the store first — clearing `~/.cache` was enough — and
then collect.

**`virtualization` needs the nested network moved first.** The guest's own
`enp1s0` sits on the outer host's `192.168.122.0/24`, and Fedora's default
network XML uses that same subnet, so libvirt refuses it:

```
error: Failed to start network default
error: internal error: Network is already in use by interface enp1s0
```

Ubuntu's packaging picked `192.168.123.0/24` by itself; Fedora's does not. The
phase deliberately never rewrites an existing network definition, so redefine it
by hand and rerun the phase:

```bash
sudo virsh net-dumpxml --inactive default > /tmp/net.xml
sudo sed -i 's/192\.168\.122/192.168.123/g' /tmp/net.xml
sudo virsh net-define /tmp/net.xml && sudo virsh net-start default
sudo virsh net-autostart default
```

This is a nested-virtualization artifact, not a fault on a real machine, whose
libvirt network does not collide with itself.

An earlier VM, `silverblue43`, ran Fedora 43 Silverblue and could not bootstrap
at all: `common/packages.sh` maps `ID=fedora` to `dnf`, which an rpm-ostree
image does not ship, and `02-nix` installs Nix onto a read-only `/`. It was
replaced by this Workstation VM rather than fixed. Supporting rpm-ostree remains
unstarted work with no effort opened.

## Selectable VPN migration staging, 2026-09-23

The first implementation slice split AyuGram, Vesktop, theme registration and
shared capture ownership, and added relative executable paths to `vpn`. The
staging generation built and activated on Fedora 44. Installed command symlinks,
Vesktop's desktop entry, AyuGram's desktop and D-Bus entries, and both theme
files were present. The Vesktop launcher check passed. `vpn -- curl` reached
HTTPS through the VM's own WireGuard identity, with a different public IPv4
address from an ordinary host request.

The generated whole-host TUN configuration passed `sing-box check` and started
as a supervised root `vpn-host.service` through `/usr/bin/env` under Fedora
SELinux. Public IPv4 routed through `vpn-host0`, while the VM gateway stayed on
`enp1s0`. The resolver chose the TUN link; a direct query to its DNS returned
an A answer and no AAAA answer. A public UDP STUN binding request received
its matching response through the generated TUN. `ip route get` kept IPv4
link-local traffic on `enp1s0`, and the IPv6 link-local route selected that
physical interface too. The VM had no separate link-local peer to probe.
Ordinary HTTPS and `vpn -- curl` worked while the TUN was active. Stopping the user backend blocked ordinary HTTPS; starting
it restored a 204 response without restarting the TUN. Two `vpn-up`/`vpn-down`
cycles restored direct public routing and the original resolver and removed
`vpn-host0`. The root config held no provider credential. These observations
apply to the generated staging configuration and the VM's real WireGuard peer.
The approved daily-host TUN activation and normal-use cycle passed separately;
network-change and suspend checks remain later work.

The independent AppArmor recovery fix passed its load/unload fault-injection
checks on staging. Fedora has no restricted user namespaces, so the normal
`apparmor` phase correctly reported already satisfied without installing
profiles. Kernel-policy lifecycle checks on an enforcing AppArmor host remain
unmeasured.

## Native VPN inventory staging, 2026-09-23

Two whole-file SOPS documents now carry native WireGuard endpoint definitions,
route DNS servers, and hostname policy. The runtime compiler checked every
native entry and selected only the VM's assigned `desktop-ubuntu` peer after
its guest hostname was changed to `fedora-staging`. Its generated backend passed
`sing-box check`. After staging activation, the local proxy and `vpn -- curl`
carried real HTTPS with the VM peer. Captured `dig` returned A records and no
AAAA records; a captured public UDP STUN binding request received a matching
response. The capture had no global IPv6 route and `vpn -- curl -6` could not
resolve the destination. The generated whole-host TUN carried HTTPS
and DNS, while a simultaneous `vpn` capture still worked. Stopping the user
backend blocked whole-host traffic; restarting it restored whole-host and
capture HTTPS. `vpn-down` removed the TUN and restored the physical route and
resolver. The first TUN run exposed an old hard-coded DNS detour tag; the
runtime generator and synthetic fixture were corrected before the passing run.
The daily host activated the separately approved clean generation
`/nix/store/q73ba55i24sc6k85mjlx9x7vnlca8v62-home-manager-generation`
with the prior generation retained for rollback. Its proxy and capture carried
HTTPS; captured DNS returned A records and no AAAA records, and UDP STUN
received a matching response. IPv6 HTTPS failed without a global route. With
`vpn-up`, public HTTPS and DNS used `vpn-host0`, LAN traffic stayed on Wi-Fi,
and capture HTTPS still worked. Stopping the user backend blocked whole-host
traffic and restarting it restored whole-host and capture HTTPS. After
`vpn-down`, the root unit and TUN interface were absent, public IPv4 routed
through Wi-Fi, the Wi-Fi resolver was selected, and direct HTTPS worked.

## Concurrent VPN candidate, 2026-09-24

The installed backend stayed on the VM's assigned peer. A separate candidate
compiler mode generated two loopback named listeners and a manual default
selector from synthetic SOCKS egresses; `sing-box check` accepted the output.
The default listener reached synthetic A, named A reached A, and named B
reached B. Disabling B broke its named listener while named A still worked.
The installed VM backend was restarted afterward and its real-peer proxy
returned HTTPS 204. The current encrypted inventory passed candidate-mode
`sing-box check` without starting its second peer. Concurrent generated UDP,
DNS and IPv6 traffic remain unmeasured, as does real concurrent operation
without additional peer assignments.

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

## Seeing the guest's screen

GNOME refuses `org.gnome.Shell.Screenshot` to anything but its own screenshot
UI and the portal, so a screenshot comes from outside the guest instead:

```bash
virsh -c qemu:///system screenshot fedora /tmp/shot.ppm   # despite .ppm, a PNG
```

The framebuffer is what the guest's display shows, so nothing runs in the
guest and no session permission is involved. Sampling one pixel of it is how a
color change was measured for the theme work.

A session left locked (`gdbus call --session -d org.gnome.ScreenSaver -o
/org/gnome/ScreenSaver -m org.gnome.ScreenSaver.GetActive`) shows the lock
screen and starts no windows; `loginctl unlock-session <id>` unlocks it from a
plain SSH connection. Launch a graphical program into the session with
`systemd-run --user --unit=<name> --setenv=WAYLAND_DISPLAY=wayland-0`: started
with `&` from an SSH command it dies with the connection.

## What a VM cannot verify

The guest has no usable GPU, so anything reaching a real driver — the `nix-gpu`
phase, hardware decode, GPU-dependent rendering — has to be judged on the host.
WezTerm does open a window here with `--config front_end='"Software"'`, which is
enough to watch it recolor, but not to judge how it draws with a driver.

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
