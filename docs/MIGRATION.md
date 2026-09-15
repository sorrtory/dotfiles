# Migration Plan

## Sources and target

Evaluate these legacy sources:

1. `~/Documents/configs/` — application and desktop configuration
2. `~/Documents/scripts/` — bootstrap and personal helper scripts
3. `~/Documents/secrets/` — secrets and WireGuard material

Consolidate selected replacements under `~/Documents/dotfiles/`. Treat every legacy item as a migration candidate: retain, improve, replace, or remove it deliberately rather than copying a tree or its Git history.

VS Code snapshots move to Archive, browser userscripts move to the separate `monkeys` repository, and KeePassXC remains outside public dotfiles.

## Method

For each migration slice:

1. identify the behavior baseline and ownership boundary
2. make the smallest coherent change
3. evaluate and build without activating on the host
4. synchronize to and activate on the staging VM
5. perform objective checks and any required normal-use check
6. present the result for operator review
7. activate on the host only after explicit approval
8. commit only after review
9. remove legacy machinery only after its replacement survives normal use

Prioritize security and dependency blockers first, then daily value, then legacy removal. Use difficulty to break ties. Cleanup can accompany a slice when it is local and verifiable; major redesign remains separate.

## Initial checkpoint

The first local commit contains:

- aligned canonical documentation
- the minimal verified flake and Home Manager profile
- `scripts/bootstrap.sh`
- `scripts/bootstrap/01-host-deps.sh`
- `scripts/bootstrap/02-nix.sh`
- bootstrap interface tests

It contains no imported legacy configuration, personal script, package migration, or secret material. Scan it mechanically before review and commit; do not publish it before the next safety slice passes.

## Core milestone

### 1. Public-repository safety gate

Create a repeatable local scan for staged changes and document deliberate inspection of high-risk files. The gate must reject plaintext secrets and private age identities without treating ciphertext as an error.

### 2. Secret recovery and SOPS/age foundation

Create one age identity outside Git and store its recovery copy as an attachment in the operator's main KeePassXC vault. Create a fresh private recovery repository containing only that encrypted vault and non-sensitive documentation; do not reuse the legacy secrets repository or its history.

The public dotfiles flake exposes a small app invoked by `03-secret-recovery`, immediately after `02-nix`. It supplies `gh`, `keepassxc-cli`, and age; performs GitHub device-flow authentication when needed, which the operator may approve from any device; clones the recovery repository; prompts for the vault password through KeePassXC; and restores `~/.config/sops/age/keys.txt` without exposing the identity through the clipboard, command arguments, environment variables, or logged output. It refuses overwrites, uses mode `0600`, verifies the derived public recipient, and installs the file atomically.

Configure sops-nix with only the public recipient and establish the public-safe `secrets/` invariant before migrating ciphertext. The following `04-home-manager` phase lets the default `bootstrap.sh install` chain perform the normal secret-bearing activation after recovery.

### 3. Initial packages and development tools

Translate the package baseline into user-owned packages and explicit host prerequisites.
Use the [software installation catalog](SOFTWARE.md) to find each candidate's
selected installation mechanism and its implementation when one exists.

The first reviewed batch includes:

- standalone CLI tools selected from `curl`, `wget`, GnuPG, `tree`, `fzf`, `htop`, `bat`, `httpie`, `ripgrep`, `fd`, `wl-clipboard`, ImageMagick, ExifTool, and `tealdeer`
- global development tools: Go, Rust/Cargo, JDK 21, GCC/G++, Make, and `pkg-config`
- program-owned packages as their modules are introduced: Zsh, Git, tmux, Neovim, MPV, and Yazi
- a small `yt-dlp` bootstrap phase installing the official stable binary for explicit self-updates
- an explicit privileged Docker bootstrap phase using the official stable convenience installer, establishing target-user group membership, and providing an explicitly destructive full-reset uninstall

Review the desktop application inventory separately. Docker remains host-owned even though its explicit bootstrap phase is part of this package slice. LXD, Snap/Flatpak infrastructure, distro repositories, system groups, and comparable host integration do not belong in normal Home Manager activation.

### 4. Zsh

Let Home Manager own `.zshrc`. Preserve selected aliases, history, environment variables, options, and plugins, but remove redundant legacy setup. The host prerequisites provide a stable distro Zsh, and the explicit `login-shell` bootstrap phase selects it after Home Manager activation.

### 5. WireGuard

Recreate selected WireGuard configurations as whole-file SOPS ciphertext,
decrypted to a user-owned path. There is no privileged deployment step and
nothing for the bootstrap flow to do: `wg-quick` accepts a config file path, so
`/etc/wireguard/` is unnecessary and the configuration never lands root-owned on
disk. Bringing a whole-host interface up needs privilege and stays an explicit
runtime action; per-application tunneling needs no host interface and belongs to
§7. See `docs/DECISIONS.md`.

### 6. SSH keys and configuration

Recreate selected SSH private keys as whole-file SOPS ciphertext, and migrate
`~/.ssh/config`, `known_hosts`, and public keys as ordinary repository material
rather than as secrets. This reverses the earlier position that SSH keys stay
machine-local; `docs/DECISIONS.md` records the reversal and the risk it accepts.

This slice ran ahead of WireGuard and so established the whole-file ciphertext
conventions rather than reusing them; WireGuard now follows it. `IdentityFile`
points at the decrypted path rather than plaintext being written into `~/.ssh/`,
which keeps keys on tmpfs — OpenSSH was verified to accept a key reached that
way at the mode sops-nix assigns. Keys are selected deliberately: one that
identifies a machine rather than the operator is a candidate for removal instead
of migration.

### 7. VPN command

Implemented on §13's shared backend. `vpn PROGRAM` runs one program as the
invoking user in an on-demand, rootless capture namespace that forwards TCP and
UDP through the backend; it creates no second WireGuard client and changes no
host routing. Vesktop is the first VPNized application: its command, desktop
entry and `discord://` handler always go through the VPN. `docs/DECISIONS.md`
records the design and [VESKTOP-APPARMOR.md](VESKTOP-APPARMOR.md) the Ubuntu
policy it needs.

Verified on a staging VM bootstrapped through every phase: tunneled launches
from all three entry points, a voice call, private DNS, IPv6 through the tunnel,
refusal of an untunneled Vesktop, backend restart, capture failure, relaunch
and a dropped link. A change to a different network and a real suspend-to-RAM
are not yet verified.

Machines are bootstrapped fresh rather than migrated, so the legacy launcher and
the native `/opt/Vesktop` retire with the reinstall instead of coexisting.
Several identities, per-application identity and other Electron applications
are follow-up work.

### 8. MPV and Anime4K

Replace the absolute symlinks and manually cloned plugins with Nixpkgs MPV
scripts where they exist, and package the rest locally at the pins the legacy
manager recorded. Anime4K comes from Nixpkgs rather than a local package; its
flat shader layout is why every `input.conf` shader binding changed. The native
`mpv.conf` and `input.conf` stay readable and live-editable through
`mkOutOfStoreSymlink`.

One script is local, because Nixpkgs does not carry it and `mpv.conf` cannot
work without it: `fuzzydir` supplies the `**` syntax the subtitle and audio
search paths use.

Three legacy scripts did not survive the slice, all replaced by better-kept
equivalents rather than reproduced. `reload` is Nixpkgs' script, which reloads
automatically on a stalled cache instead of only on a key press; `input.conf`
restores the `Shift+R` the legacy one bound. The vanilla-OSC fork gives way to
`uosc`, which draws thumbfast's previews natively and disables mpv's builtin
OSC itself. `show_filename` is gone entirely: it was a pinned dependency for a
single `show-text ${filename}` binding, which `input.conf` now does directly.

`thumbfast` is the one place the Nixpkgs pin was not good enough. It trails
upstream by the commit that stops the thumbnailer subprocess being spawned
with a stripped environment on Linux, so the module overrides its source to
upstream head. `mpv.conf` is otherwise migrated verbatim apart from three settings that all
concern reaching an unknown machine's GPU: `hwdec` becomes `auto-safe`, video
output becomes a list ending in software `x11` so a machine MPV cannot
accelerate still shows a picture, and `gpu-api` becomes `auto`. The drivers
themselves come from Nixpkgs through the MPV wrapper, because a Nix program
cannot use the distro's; see `docs/DECISIONS.md`.

Shipped and confirmed under normal use on the host. The legacy
`~/Documents/configs/mpv/` tree is deliberately left in place: it is retired
with the rest of the legacy repository when the operator reinstalls, not by
this slice.

### 9. GNOME

Specify and ticket intentional GNOME migration. Capture the current dconf state as evidence, retain deliberate preferences, and omit incidental runtime keys.

### 10. Neovim

Let Home Manager own the Neovim package and expose the native Lua
configuration through `mkOutOfStoreSymlink`. Nix does not own the plugin set:
`lazy.nvim` keeps its `lazy-lock.json` pins and mason keeps installing
language servers and formatters, because translating a working 16-plugin
configuration into Nix would trade live editability for reproducibility this
repository does not need for an editor.

Nix must supply what that configuration assumes is already present. Ten of the
sixteen declared language servers are npm packages, so Node.js becomes a
selected global user tool and the `fnm` PATH shim in `init.lua` is deleted
rather than reproduced.

The legacy `.vimrc` moves across as ordinary repository material, not as a
migration slice. It has no plugins, the operator does not use it, and its own
header describes it as a drop-in for remote servers, so `~/.vimrc` is a store
symlink rather than a live-editable one and Vim itself stays undeclared.

One mechanism detail surfaced during the work: `programs.neovim` writes its own
generated `init.lua` into the directory this slice links whole, which cannot
coexist with owning that directory. `sideloadInitLua` hands the generated Lua
to the wrapper instead, and since this configuration generates none, nothing is
lost.

A fresh machine is the one place lazy.nvim, mason and nvim-treesitter all
install at once, and the first staging start surfaced two things a
long-lived host hides. mason's default provider resolves the registry through
`api.mason-registry.dev`, which is unreachable from this network, so the
configuration asks GitHub first. And nvim-treesitter's 36 parallel grammar
installs flood the message area with hit-enter prompts, which Neovim 0.12's
experimental `ui2` message UI replaces.

Shipped on staging. A bootstrapped VM installed every plugin, and the fixed
configuration then installed all 36 grammars and all 25 mason packages there
with no prompt, run from a copy of `configs/nvim/` against empty data
directories. A start from the mirrored repository itself was not seen before
that VM was reset.

### 11. tmux

Let Home Manager own the tmux package and its three plugins, retiring TPM and
its network clone from the fresh-machine flow. Keep `tmux.conf` readable and
live-editable through `mkOutOfStoreSymlink`, since `prefix + r` reloads it in
place and the file is tuned often.

That pairing is why the module does not use `programs.tmux`: that option
generates `tmux.conf` itself and offers no way to decline, so the module
declares the package with `home.packages` and links each plugin into
`~/.config/tmux/plugins/` under its upstream name. Reproducing TPM's layout is
what repairs `prefix + Ctrl+d`, which was already broken on the legacy host: it
names resurrect's own `save.sh` beneath a directory nothing ever created.

`Ctrl+h/j/k/l` navigation is one feature split across this section and the
Neovim one; the tmux `is_vim` bindings and `vim-tmux-navigator` are each half
of it.

Shipped on staging, where the operator found tmux working. `Ctrl+h/j/k/l` was
never pressed across a real Neovim split and tmux pane: its tmux condition was
checked on the host, and the operator closed the slice on that. Continuum's
save hook cannot be observed while another tmux server runs, and is left to the
review of `tmux.conf` itself.

### 12. Yazi

Let Home Manager own Yazi, its native TOML configuration, and the single
pinned plugin the legacy manager restored. This removes the last legacy Snap
dependency other than the browser.

Nixpkgs carries dozens of Yazi plugins but not `copy-file-contents`, so it is a
small local package pinned at the revision `configs/yazi/package.toml` records.
That manifest stays in the repository as the record of the pin, is regenerated
by `ya pkg add` rather than edited by hand, and is deliberately not linked into
the config directory, where only `ya pkg` would read it.

The slice then went past the legacy setup on purpose. "Copy" was one key there,
and it is three operations: the file onto the system clipboard as
`text/uri-list` (`y`, through the packaged `clipboard.yazi`), its contents as
text (`Ctrl+y`), and its path (`c c`, already a Yazi preset). `Alt+Shift+Y`
copies contents behind each file's path in a code fence, which is what the
newer plugin revision buys. `!` opens a real `$SHELL` in the hovered directory,
which Yazi's `;` and `:` command boxes are not. `xclip` joins `wl-clipboard`,
because both the tmux copy chain and the clipboard plugin pick their tool by
session type.

Shipped and confirmed on staging, where the operator copied file contents with
`Ctrl+y`. That VM has no snapd, so `snap list yazi` means something only on a
host that has it.

### 13. sing-box

Replace the deprecated LXD proxy container with `sing-box` as an unprivileged
local proxy. It is a granular per-application proxy, not a transparent VPN:
applications opt in through the proxy environment variables or their own
settings. UDP-dependent applications use §7's VPN command into the same
backend.

Run it as a `systemd` user service with no privilege, tunneling through a
userspace WireGuard endpoint so no kernel module, TUN device, routing change,
or resolver change is involved. Expose a `mixed` inbound on
`127.0.0.1:1080` and an `http` inbound on `127.0.0.1:3128`, which are exactly
the endpoints the existing `proxy-on` shell alias already exports.

The WireGuard migration already supplies whole-file SOPS ciphertext. Select
one exclusive peer identity per machine, generate the sing-box configuration
on tmpfs at startup, and use it for both entry points. The initial local proxy
does not require TUN support or a sing-box upgrade; §7's namespace capture
does. The explicit `user-linger` phase enables startup before login.

The local proxy service is implemented and verified on staging, including
restart, cleanup and startup before login after reboot. Namespace capture and
Discord UDP are delivered by §7.

LXD, its container, Shadowsocks, and the legacy `iptables` bridge helper are
retired rather than migrated. The operator retires the host-side machinery by
reinstalling, so the slice itself removes documentation and repository
references, not running host state.

## Additional candidates

Reassess remaining candidates after the core milestone or when dependency analysis promotes one. Neovim, tmux, and Yazi were promoted into the core milestone as slices 10 to 12.

Firefox under Nix was considered for the core milestone and deliberately left
out. Taking it off the Ubuntu Snap would make its profile predictable, allow
declarative preferences, and let it read the encrypted PAC file that Snap
confinement denies — but none of that is load-bearing for the fresh-machine
flow, and Snap-supplied Firefox keeps working. The trade is also not free: Nix
would move browser security updates from Mozilla's cadence onto `flake.lock`
bumps. The `firefox-nix` effort holds the specified work at `needs-triage`
until this is reassessed. It depends on the sing-box slice, which produces the
PAC it wants to encrypt.

Splitting the KeePassXC vault is tracked by the `vault-split` effort: a small
recovery vault behind a long password, and a daily vault unlocked by a password
plus a key file that sops-nix delivers. It supplies the KeePassXC native
messaging host `firefox-nix` needs, and its Firefox password settings wait for
that effort's declared profile.

The Snap sourcing policy that effort records — `snapd` stays as host-owned
infrastructure, and no software this repository declares comes from Snap — is
independent of Firefox's fate and can land on its own. Kitty, Hyprland, Wofi, dunst, tmuxinator, Obsidian configuration, and the legacy VS Code snapshots were reviewed and deliberately dropped rather than deferred. The remaining candidates are selected helper scripts and the desktop applications still awaiting review.

Use `mkOutOfStoreSymlink` only where live editing is intentional. Do not translate a readable native format merely for aesthetics.

## Legacy retirement

Mine the legacy manager, link script, installer, package list, secrets-fetch logic, and manually maintained plugin checkouts for selected requirements. Archive or delete each only after its replacement is verified. Do not recreate generic legacy provisioning inside Nix.

## Fresh-machine flow

The intended flow is:

1. clone the public dotfiles repository
2. set this machine's `dotfiles.vpn.identity`, then run `scripts/bootstrap.sh install`
3. let `01-host-deps` establish bootstrap prerequisites and `02-nix` install Nix
4. authenticate GitHub when `03-secret-recovery` invokes the flake recovery app and clones the private recovery repository
5. enter the main KeePassXC vault password so the phase can restore and verify the private age identity
6. let `04-home-manager` build and activate the normal profile with sops-nix secrets available
7. let `login-shell` select the host-owned Zsh
8. let `user-linger` enable user services before login and after logout
9. let `apparmor` install the user-namespace allowances where Ubuntu restricts them
10. open a new login session
11. run explicit privileged host setup where required, including the GPU driver choice in the README's "GPU-accelerated programs" section
12. authenticate any remaining mutable sessions once on that machine

The repository currently targets the `z` user on `x86_64-linux`; broader host/user parameterization is a later migration decision.
