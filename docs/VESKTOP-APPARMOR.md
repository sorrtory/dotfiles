# AppArmor allowances for Vesktop and `vpn`

## Why they are needed

Ubuntu sets `kernel.apparmor_restrict_unprivileged_userns=1`. These programs in
this repository need unprivileged user namespaces and are denied without an
allowance:

- **sing-box capture** creates the rootless network namespace that `vpn` and
  Vesktop run in. Without its allowance `vpn-capture.service` fails and every
  tunneled launch reports that the capture namespace did not start.
- **Vesktop's Electron** builds its renderer sandbox from user namespaces.
  Denied, it falls back to the setuid `chrome-sandbox` helper, which cannot be
  setuid in the Nix store, and aborts with the `chrome-sandbox` error before any
  VPN is involved. Native installs avoid this only because their helper is setuid.
- **VS Code and Obsidian** fail the same way, for the same reason, although
  neither uses the VPN. Ubuntu ships allowances for them, but those attach to
  `/usr/share/code` and `/opt/Obsidian` and never match a Nix store path. Both
  reach the network through the local HTTP proxy, since they need no UDP.

The legacy root-run launcher needed neither: root created its namespace, and
the native `/opt/Vesktop` shipped the setuid helper.

## What is installed

`modules/apparmor.nix` generates one profile per registered executable from
the template beside it, and links them to `~/.local/share/dotfiles/apparmor/`.
Modules register them through
`dotfiles.apparmor.usernsAllowances.<name> = { executable; usedBy; }`:

- `dotfiles-sing-box`, attached to the exact sing-box binary capture runs.
- `dotfiles-electron-43`, attached to Nixpkgs' unwrapped Electron 43. Vesktop
  registers it when `dotfiles.vpnizedApps.vesktop.enable` is set, and Obsidian
  registers it too. They run the same binary, so they share one profile.
- `dotfiles-vscode`, attached to the Electron bundled as VS Code's
  `lib/vscode/code`.

The build fails if an attachment is not an ELF executable, or is missing from
the closure of a package listed in `usedBy`. That catches an update that moves
Vesktop or Obsidian to another Electron. Two modules registering one name with
different executables fail evaluation.

Each profile is `flags=(unconfined)` with `userns,`: it permits namespace use
and imposes **no** filesystem or network confinement. It attaches to one store
path, never to a wrapper or a wildcard over `/nix/store`.

## Security tradeoff

The global restriction stays on, Electron's sandbox stays on, no setuid helper
is installed and no host-root identity is granted. The allowances do expose
additional kernel functionality to these executables, which is the attack
surface Ubuntu's restriction reduces, and anything else run with the same
executable gets it too: the allowance is executable-scoped, not scoped to
Vesktop's or Obsidian's code, or to one sing-box configuration. `unshare`, `nsenter` and Bash
receive nothing.

Do not substitute `--no-sandbox`, change permissions in `/nix/store`, or turn
the global restriction off to make an error disappear.

## Installing and updating

Home Manager activation never installs policy or invokes sudo. The numbered
`apparmor` bootstrap phase does, after `home-manager`:

```bash
./scripts/bootstrap.sh install apparmor
```

It does nothing where the restriction is off. Otherwise it validates every
generated profile without loading it, then installs each to
`/etc/apparmor.d/` as root-owned `0644` and reloads it, and removes installed
`dotfiles-*` profiles that are no longer generated. AppArmor loads them again
on boot. Restart Vesktop and tunneled programs after a change.

A flake update that moves sing-box or Electron changes the attachment paths.
Activation compares the generated profiles with the installed ones and warns
with the command above when they differ; until the phase runs again the
affected program is denied exactly as described in the first section.
`./scripts/bootstrap.sh status apparmor` reports which profile is missing,
stale or left over.

## Removal

Close Vesktop and tunneled programs, then:

```bash
./scripts/bootstrap.sh uninstall apparmor
```

This unloads and deletes only `dotfiles-*` profiles. The startup failures above
are expected again afterwards while the restriction is on.

## Verification

A window appearing establishes neither sandboxing nor capture. Check that the
global sysctl is still `1`; that `unshare --user --map-root-user true` is still
denied; that Vesktop's main process shares capture's network namespace; and
that a sandboxed child has distinct user/PID/network namespaces, zero effective
capabilities, `NoNewPrivs: 1` and `Seccomp: 2`.

### Staging evidence — 2026-09-14

With hand-installed profiles attached to the same paths the generator now
produces: before the Electron profile, `vesktop --version` aborted with the
setuid-helper error; afterwards it printed `Vesktop v1.6.5`. The restriction
stayed `1` and plain `unshare` stayed denied. Launched through `vpn`, Vesktop's
main process shared capture's network namespace, distinct from the session's;
a sandboxed child showed isolated namespaces, zero capabilities, no-new-privs
and seccomp filtering. Discord HTTPS and native STUN worked through capture,
and the operator completed a real voice call.

### Staging evidence — VS Code and Obsidian, 2026-09-15

On the Ubuntu GNOME VM (Ubuntu 26.04.1, restriction `1`), before the phase ran,
both applications aborted. Obsidian logged the setuid-helper error, and the
kernel logged `userns_create` from their executables followed by a `sys_admin`
denial.

After `./scripts/bootstrap.sh install apparmor` loaded `dotfiles-electron-43`,
`dotfiles-sing-box` and `dotfiles-vscode`, they were started through their
GNOME keybindings:

- **Both windows appeared.** Every process of VS Code carried the
  `dotfiles-vscode` label, and every process of Obsidian `dotfiles-electron-43`.
- **The kernel logged no further denials for them,** while plain `unshare`
  stayed denied.
- **Chromium's sandbox held.** Zygotes ran in their own user namespace with
  `NoNewPrivs: 1`. VS Code's sandboxed child and Obsidian's GPU and broker
  processes showed `Seccomp: 2`, and utility processes started with
  `--enable-sandbox` or `--service-sandbox-type`.
- **Obsidian's renderer runs with `--no-sandbox`** and no seccomp filter.
  Obsidian launches its renderer that way itself, so it is not an effect of
  the allowance.
- **Both used the HTTP proxy.** A stand-in listener on `127.0.0.1:3128` logged
  VS Code's `CONNECT`s to the marketplace, its CDN and telemetry, and
  Obsidian's to `releases.obsidian.md`.

References: [Ubuntu's per-application policy explanation](https://ubuntu.com/blog/ubuntu-23-10-restricted-unprivileged-user-namespaces),
[Chromium's alternatives and their tradeoffs](https://chromium.googlesource.com/chromium/src/+/main/docs/security/apparmor-userns-restrictions.md).
