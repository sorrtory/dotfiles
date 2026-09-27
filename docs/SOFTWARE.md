# Software installation catalog

This is the human-readable source of truth for the selected user environment:
what each program is for, how it is installed, and where that installation is
defined. Entries qualified by a distribution, such as the AppArmor allowances
Ubuntu needs, apply only there. It covers the minimal shared toolkit and explicit
installation exceptions. Dependencies belonging only to a deferred desktop or
program configuration are added when that configuration is actually migrated.
Linked implementation files remain authoritative for exact mechanics, and
`flake.lock` remains authoritative for Nix package versions.

## Entry interface

Entries are alphabetical and use the same fields:

- **Purpose** is required: one sentence describing the software's role here.
- **State** is required: `Active`, `Temporarily disabled`, `Deferred`,
  `Not selected`, `Retired`, or `External`. `External` means host-owned
  software this repository does not install.
- **Owner** is required for `Active` and `Temporarily disabled` entries. It is
  one link to the file that installs or declares the software. Deferred,
  unselected, retired and external entries have no repository owner.
- **Used by** appears only for direct consumers, with links to their
  implementations. A package pin, installer, activation phase or reference
  document is explained in prose instead of being labelled a consumer.
- **Applies on** appears only when a choice is conditional on a distro or
  session type.

Prose after the fields records installation mechanics, constraints, decisions
and removal conditions when needed. Frequency of personal use is not a state:
it changes independently of the repository's software choices.

## Catalog

### age

- **Purpose:** Encrypt and decrypt SOPS data.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [recovery app](../packages/recover-age-identity.nix).

Home Manager global user tool; the same store path is first fetched by the
recovery app, which needs it before Home Manager exists.

### Anime4K

- **Purpose:** MPV video shaders.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

Nixpkgs `anime4k`, symlinked into the MPV config directory as a whole store
path.

### Ansible

- **Purpose:** Run playbooks and manage remote hosts.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### AppArmor `userns` allowances

- **Purpose:** Let capture's sing-box and the Electron of Vesktop, Obsidian and VS
  Code use unprivileged user namespaces on Ubuntu.
- **State:** Active.
- **Owner:** [AppArmor module](../modules/apparmor.nix).
- **Applies on:** Ubuntu.

Home Manager generates exact-path profiles from the executables registered by
program modules. The explicit [apparmor bootstrap phase](../scripts/bootstrap/10-apparmor.sh) installs them with sudo.
Normal activation only warns when the installed profiles are stale.

### APT repository helpers

- **Purpose:** Add third-party Debian repositories.
- **State:** Not selected.

Legacy-only host tooling; do not reproduce as a global user package.

### `aria2`

- **Purpose:** Multi-connection download utility.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [download command](../scripts/bin/download.sh).

Home Manager installs `aria2` as a global tool. It is also the plain-file
backend of `download`. The command sets `-x8 -s8` because aria2's default of
one connection per server would make it no better than wget for this use.
The [scripts module](../modules/scripts.nix) includes it in `download`'s
runtime inputs.

### Audacity

- **Purpose:** Audio editor.
- **State:** Deferred.

Deferred to desktop application review.

### AyuGram (`ayugram-desktop`)

- **Purpose:** Telegram client, including calls.
- **State:** Active.
- **Owner:** [VPNized apps module](../modules/programs/vpnized-apps/default.nix).
- **Used by:** [GNOME module](../modules/desktops/gnome.nix).

The VPNized apps module installs Nixpkgs `ayugram-desktop` and routes its
command, desktop entry and `tg://` handler through the VPN command. It is a
native Qt binary, so it needs no AppArmor allowance. Login and session state
remain machine-local. `<Super>m` opens it.

### bat

- **Purpose:** Syntax-highlighting file viewer.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Bun

- **Purpose:** JavaScript runtime referenced by legacy shell configuration.
- **State:** Deferred.

Deferred; projects own runtimes unless a global requirement is selected.

### `ca-certificates`

- **Purpose:** Host TLS trust store.
- **State:** Active.
- **Owner:** [host-deps phase](../scripts/bootstrap/02-host-deps.sh).

Distro package, refreshed by the `host-deps` bootstrap phase when no CA bundle
sits at a path Nix probes; Nix needs one to export `NIX_SSL_CERT_FILE`.

### Chrome

- **Purpose:** Web browser.
- **State:** Deferred.

Legacy vendor-repository installer; deferred to desktop application review.

### Clang (`clang++`)

- **Purpose:** C and C++ compiler for builds that link host libraries.
- **State:** Active.
- **Owner:** [native-toolchain phase](../scripts/bootstrap/13-native-toolchain.sh).

Host package through the `native-toolchain` bootstrap phase, with the GTK development
files it compiles against; a project needing another version overrides it from a
Nix development shell.

### `clang-tools` (clangd)

- **Purpose:** C and C++ language server, formatter and linter.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; the language server and formatters only,
which collide with nothing, while the compiler above is host-owned.

### Claude Code (`claude`)

- **Purpose:** AI coding assistant.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool from the independently pinned `sadjow/claude-code-nix`
native-binary package; its launcher always selects the local sing-box HTTP proxy;
authentication remains machine-local.

The package input is pinned in the [flake](../flake.nix).

### CMake

- **Purpose:** C and C++ build system generator.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; the generator half of the C and C++
toolchain, driving the Make already present.

### Codex (`codex`)

- **Purpose:** AI coding assistant.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool from the independently pinned `sadjow/codex-cli-nix`
native-binary package; its launcher always selects the local sing-box HTTP proxy;
authentication remains machine-local.

The package input is pinned in the [flake](../flake.nix).

### `convert-to`

- **Purpose:** Convert media and image files already on disk.
- **State:** Active.
- **Owner:** [scripts module](../modules/scripts.nix).

Personal script exposed in `~/.local/bin`; picks a recipe from what `ffprobe`
reports, removes nothing unless `-R` is given, and refuses a batch
before encoding if an output exists.

The command source is the [convert-to script](../scripts/bin/convert-to.sh).

### curl

- **Purpose:** HTTP transfer tool.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager installs curl as a user tool, while the [host-deps phase](../scripts/bootstrap/02-host-deps.sh) requires the host copy during bootstrap.

### DBeaver

- **Purpose:** Database client.
- **State:** Deferred.

Legacy vendor-repository installer; deferred to desktop application review.

### dconf Editor (`dconf-editor`)

- **Purpose:** Graphical dconf editor.
- **State:** Active.
- **Owner:** [GNOME module](../modules/desktops/gnome.nix).

Home Manager GNOME tool from Nixpkgs, the same on every distro.

### delta (`git-delta`)

- **Purpose:** Syntax-highlighting pager for Git diffs.
- **State:** Active.
- **Owner:** [Git module](../modules/programs/git.nix).

Nixpkgs `delta` through Home Manager's `programs.delta`, with Git integration
enabled.

### direnv (with `nix-direnv`)

- **Purpose:** Per-directory environments, activating project development shells.
- **State:** Active.
- **Owner:** [direnv module](../modules/programs/direnv.nix).

Home Manager module owning the package; `nix-direnv` caches the evaluated shell
and keeps a GC root for it.

### dnsmasq

- **Purpose:** Legacy namespace DNS helper.
- **State:** Not selected.

Not selected; capture's sing-box answers DNS inside the namespace.

### Docker

- **Purpose:** Container runtime.
- **State:** Active.
- **Owner:** [Docker bootstrap phase](../scripts/bootstrap/07-docker.sh).

Official stable convenience installer in an explicit host phase; adds the invoking
user to the `docker` group; uninstall removes packages, repository setup,
and all local Docker data.

### `download`

- **Purpose:** Fetch media through one front door.
- **State:** Active.
- **Owner:** [scripts module](../modules/scripts.nix).

Personal script exposed in `~/.local/bin`; the URL chooses yt-dlp, gallery-dl,
aria2c, spotdl or gdown; `--as` selects a supported result, and
`$PROXY` follows the chosen backend.

The command source is the [download script](../scripts/bin/download.sh).

### ExifTool

- **Purpose:** Media metadata inspector.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### eza

- **Purpose:** Terminal file listing.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [Zsh module](../modules/programs/zsh.nix).

Home Manager global user tool; Zsh aliases `la` (all), `ll`
(detailed with Git status) and `lt` (two-level tree) use icons and put
directories first; `ls` stays the system command.

### `fd`

- **Purpose:** Filesystem search tool.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool, replacing Ubuntu's `fdfind` command name.

### FFmpeg

- **Purpose:** Audio and video processing shared by scripts, `yt-dlp`, and
  MPV workflows.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Firefox

- **Purpose:** Web browser.
- **State:** Deferred.

Installing Firefox through Nix remains deferred to desktop application review.
The [Firefox module](../modules/programs/firefox.nix) already manages selected
profile files for an existing browser; login and profile state remain
machine-local. The [Firefox effort](../.scratch/firefox-nix/map.md) tracks the
package and profile migration.

### Flatpak

- **Purpose:** Host-level desktop application infrastructure.
- **State:** External.

Host-owned; excluded from normal Home Manager activation.

### fnm

- **Purpose:** Node.js version manager referenced by retained shell configuration.
- **State:** Not selected.

Not selected; its `PATH` does not survive a GUI or session launch, which a
global Nix-provided Node does not need a workaround for.

### `fzf`

- **Purpose:** Interactive fuzzy finder.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `gallery-dl`

- **Purpose:** Image-gallery and booru downloader.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [download command](../scripts/bin/download.sh).

Gallery and post backend of the `download` command, from the unstable pin. Not
a bootstrap phase: stable releases carry no Linux binary since v1.32.0, so there
is nothing to verify and `gallery-dl -U` cannot reach the stable channel.

The unstable package input is declared in [flake.nix](../flake.nix).

### GCC and G++

- **Purpose:** C and C++ compilers.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### GDB

- **Purpose:** Debugger for compiled languages.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `gdown`

- **Purpose:** Google Drive public file and folder downloader.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [download command](../scripts/bin/download.sh).

Home Manager global user tool and runtime backend of `download`, both from the
unstable pin.
The [scripts module](../modules/scripts.nix) includes it in `download`'s
runtime inputs.

### Git

- **Purpose:** Version control.
- **State:** Active.
- **Owner:** [Git module](../modules/programs/git.nix).

Host prerequisite for bootstrap; user package and configuration owned by a Home
Manager program module.

### GitHub CLI (`gh`)

- **Purpose:** GitHub from the terminal; signs in to clone the recovery vault.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [recovery app](../packages/recover-age-identity.nix).

Home Manager global user tool; the same store path is first fetched by the
recovery app; its sign-in stays machine-local session state.

### gitleaks

- **Purpose:** Repository secret scanner.
- **State:** Active.
- **Owner:** [Flake](../flake.nix).

Nix development-shell tool used by repository checks.

### GNOME Extensions Manager (`gnome-shell-extension-manager`)

- **Purpose:** Manage GNOME Shell extensions.
- **State:** Active.
- **Owner:** [GNOME module](../modules/desktops/gnome.nix).

Home Manager installs Nixpkgs `gnome-extension-manager`, replacing the apt
package. The module adds `glib-networking` to its inputs: without it, the app
has no GIO TLS backend off NixOS and cannot reach extensions.gnome.org. Drop
the override when Nixpkgs carries the missing input; the defect and removal
condition are recorded in [WORKAROUNDS.md](WORKAROUNDS.md#gnome-extension-manager).
Extensions installed by hand through the manager stay unmanaged.

### GNOME Shell extensions: Blur my Shell, Clipboard Indicator, Hide Top Bar, Run or Raise, User Themes

- **Purpose:** Shell appearance, clipboard history, auto-hiding top bar,
  application window shortcuts, and loading Rewaita's generated Shell CSS.
- **State:** Active.
- **Owner:** [GNOME module](../modules/desktops/gnome.nix).

Nixpkgs `gnomeExtensions` through Home Manager's `programs.gnome-shell`, which owns
`enabled-extensions`; replaces the archived `gnome-shell-extension-installer`. Ubuntu's default extensions
stay distro-provided and enabled by the session mode.

### GNOME Tweaks (`gnome-tweaks`)

- **Purpose:** Configure additional GNOME preferences.
- **State:** Active.
- **Owner:** [GNOME module](../modules/desktops/gnome.nix).

Home Manager GNOME tool from Nixpkgs, the same on every distro; its closure
carries its own GNOME Shell and Mutter (about 850 MiB), accepted over a per-distro
install.

### GnuPG

- **Purpose:** OpenPGP tooling.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Go

- **Purpose:** Go compiler and tools.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; replaces the downloaded system
toolchain.

### Gradia

- **Purpose:** Screenshot annotation.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [GNOME module](../modules/desktops/gnome.nix).

Home Manager global desktop application from Nixpkgs, replacing the legacy
Flatpak; `<Shift>F11` takes an interactive screenshot through the desktop
portal.

### GTK 3 development files

- **Purpose:** Headers and `pkg-config` data for native Linux desktop builds.
- **State:** Active.
- **Owner:** [native-toolchain phase](../scripts/bootstrap/13-native-toolchain.sh).

Host package through the `native-toolchain` bootstrap phase (`gtk3-devel`,
`libgtk-3-dev`, `gtk3`); Flutter's Linux desktop target links them.

### Home Manager

- **Purpose:** Build and activate the user environment.
- **State:** Active.
- **Owner:** [home profile](../home.nix).

The [flake](../flake.nix) exposes this profile. After secret recovery, the [home-manager bootstrap phase](../scripts/bootstrap/05-home-manager.sh) builds and activates it.

### `htop`

- **Purpose:** Interactive process viewer.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### HTTPie

- **Purpose:** Human-oriented HTTP client.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### ImageMagick

- **Purpose:** Image conversion and processing.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `iproute2`

- **Purpose:** Network namespace and interface commands.
- **State:** Active.
- **Owner:** [VPNized apps module](../modules/programs/vpnized-apps/default.nix).

Private runtime input of the VPN command's namespace-entry helper; not a host
prerequisite.

### iptables

- **Purpose:** Legacy namespace NAT helper.
- **State:** Not selected.

Not selected; namespace capture uses a TUN forwarding to the local proxy and needs
no NAT.

### JDK 21

- **Purpose:** Java compiler and runtime.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; replaces separate default JDK and JRE
packages.

### jq

- **Purpose:** Command-line JSON processor, also the runtime JSON generator for
  the local proxy and capture.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [Proxy module](../modules/programs/sing-box/default.nix), [VPNized apps module](../modules/programs/vpnized-apps/default.nix).

Home Manager global user tool; the same store path is also a private runtime
dependency of the packaged generators.

### KeePassXC

- **Purpose:** Password, recovery-code, and private age-identity storage.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [recovery app](../packages/recover-age-identity.nix).

The [secret-recovery phase](../scripts/bootstrap/04-secret-recovery.sh) runs the recovery app before Home Manager exists. That app fetches the same store path for `keepassxc-cli`. The database remains outside public dotfiles.

### Kitty

- **Purpose:** Terminal emulator.
- **State:** Deferred.

Deferred to desktop application and native-config review.

### lazygit

- **Purpose:** Terminal Git client.
- **State:** Not selected.

Not selected; nothing in the Neovim configuration ever referenced it, so no
migration was waiting on it.

### LibreOffice

- **Purpose:** Office suite.
- **State:** Deferred.

Deferred to desktop application review.

### LXD

- **Purpose:** System container manager used by the legacy proxy.
- **State:** Retired.

Retired with the legacy proxy rather than migrated; see
[the VPN and proxy decision](DECISIONS.md#scripts-and-privileged-networking).

### Make

- **Purpose:** Build automation.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### MesloLGS Nerd Font (`nerd-fonts.meslo-lg`)

- **Purpose:** Icon glyphs for Neovim's completion menu, lualine and neo-tree, and
  Yazi's file-type icons.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; `fonts.fontconfig.enable` is also turned on, since it defaults
to off outside NixOS and the package would otherwise sit unseen by non-Nix
applications; VS Code names it (as `MesloLGS Nerd Font Mono`) for its terminal, but selecting
it in Ptyxis is a manual preference, not declared here.

### MPV

- **Purpose:** Media player.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

Home Manager `programs.mpv` with native `mpv.conf` and `input.conf`.

### MPV script: `fuzzydir`

- **Purpose:** Recursive `**` in MPV subtitle and audio search paths.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

The [local package](../packages/mpv-fuzzydir.nix) supplies the recursive syntax that `mpv.conf` uses.

### MPV script: `thumbfast`

- **Purpose:** Seek-bar thumbnail previews.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

Nixpkgs `mpvScripts.thumbfast` with its source overridden to upstream head,
one commit ahead. See the [workaround](WORKAROUNDS.md#mpvscriptsthumbfast)
for the defect and removal condition.

### MPV script: `uosc`

- **Purpose:** On-screen controller; draws thumbfast previews.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

Nixpkgs `mpvScripts.uosc`; disables MPV's builtin OSC itself.

### MPV scripts

- **Purpose:** MPV behavior extensions.
- **State:** Active.
- **Owner:** [MPV module](../modules/programs/mpv.nix).

Nixpkgs `mpvScripts` where they exist. `fuzzydir` is the only local package
because Nixpkgs lacks it.

### Neovim

- **Purpose:** Text editor and default `$EDITOR`.
- **State:** Active.
- **Owner:** [Neovim module](../modules/programs/neovim.nix).

Home Manager program package; the native Lua tree in `configs/nvim` is one
live-editable symlink, and `lazy.nvim` with mason keeps the plugins.

### Neovim image preview (`image.nvim`)

- **Purpose:** Show Markdown images in place with Markview preview, or at the
  cursor while editing; `<leader>mi` toggles images in both modes.
- **State:** Temporarily disabled.
- **Owner:** [Image plugin](../configs/nvim/lua/plugins/image.lua).
- **Used by:** [image modes](../configs/nvim/lua/markdown_images.lua).

Rendering works, but normal use is very laggy. It uses ImageMagick and Sixel in WezTerm; the [tmux configuration](../configs/tmux/tmux.conf) passes graphics through. The [workaround entry](WORKAROUNDS.md#imagenvim) records the rendering defect separately from this performance problem.

### NetworkManager applet

- **Purpose:** Desktop interface for the host-owned network manager.
- **State:** Deferred.

Host-integrated desktop software; deferred to desktop migration.

### Ninja

- **Purpose:** Build backend for generated build systems.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; the generator CMake presets usually
name.

### Nix

- **Purpose:** User-environment package and build system.
- **State:** Active.
- **Owner:** [Nix bootstrap phase](../scripts/bootstrap/03-nix.sh).

Multi-user installation through bootstrap.

### `nixd`

- **Purpose:** Nix language server.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [Neovim LSP spec](../configs/nvim/lua/plugins/lsp.lua).

Home Manager global development baseline, not mason like Neovim's other servers:
the mason registry carries no nixd, only the unmaintained `rnix-lsp`. The
editor spec enables it by name, since `nvim-lspconfig` already supplies its command
and root markers.

### `nixfmt`

- **Purpose:** Nix formatter (RFC 166 style).
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).
- **Used by:** [flake](../flake.nix), [Neovim format spec](../configs/nvim/lua/plugins/format.lua).

Home Manager global development baseline; Neovim's conform runs it on save, and
the flake's `formatter` output makes `nix fmt` use the same one.

### Node.js

- **Purpose:** JavaScript runtime.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; selected globally because mason installs ten of
Neovim's language servers as npm packages that need Node at runtime.

### OBS Studio (`obs-studio`)

- **Purpose:** Recording and streaming.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Obsidian

- **Purpose:** Knowledge-base application.
- **State:** Active.
- **Owner:** [Obsidian module](../modules/programs/obsidian.nix).

Home Manager program package started with `--proxy-server` for the local HTTP proxy
while it is enabled; needs the `apparmor` phase on Ubuntu; vaults and session
state remain machine-local.

### Oh My Zsh and Zsh plugins

- **Purpose:** Interactive shell framework and extensions.
- **State:** Active.
- **Owner:** [Zsh module](../modules/programs/zsh.nix).

Home Manager packages; selected built-ins plus packaged autosuggestions and syntax
highlighting, all colored from the palette, with a generated oh-my-zsh theme named
`dotfiles`.

### OpenSSH client

- **Purpose:** SSH access used by Git and remote workflows.
- **State:** External.

The client is a host-owned prerequisite. Home Manager links the native
[`~/.ssh` configuration](../modules/programs/ssh.nix), and
[sops-nix](../modules/secrets.nix) delivers two selected private keys and the
host-identifying config fragment on tmpfs. Rotation and legacy retirement
remain in the [SSH effort](../.scratch/ssh-keys/map.md).

### pipx

- **Purpose:** Isolated Python application installer.
- **State:** Deferred.

Legacy dependency of Python `tldr`; replaced for that use and otherwise
deferred.

### `pkg-config`

- **Purpose:** Native build dependency discovery.
- **State:** Active.
- **Owner:** [native-toolchain phase](../scripts/bootstrap/13-native-toolchain.sh).

Host package through the `native-toolchain` bootstrap phase; the Nixpkgs binary
searches only its own store path, so on `PATH` it hid the host's
`.pc` files, and Nix development shells bring their own.

### pnpm

- **Purpose:** JavaScript package manager.
- **State:** Deferred.

Deferred; projects own package managers unless a global requirement is selected.

### Powerlevel10k

- **Purpose:** Zsh prompt theme.
- **State:** Retired.

Retired; the legacy shell selected `flazz` and had no Powerlevel10k config
or theme checkout, and the prompt is now generated from the palette.

### Python

- **Purpose:** Python runtime and development environment.
- **State:** Not selected.

Not selected as a global baseline; projects own required versions.

### Rewaita

- **Purpose:** Recolor GTK, GNOME Shell and Firefox while retaining Adwaita's
  structure.
- **State:** Active.
- **Owner:** [GNOME module](../modules/desktops/gnome.nix).

Home Manager installs an upstream 1.1.7 pin because Nixpkgs 1.1.1 lacks the
CLI and Firefox support this setup needs. The selected repository palette is
applied at activation and GNOME login; Rewaita's Fine Tune preferences remain
mutable. The [workaround entry](WORKAROUNDS.md#rewaita) records when the pin
can be removed.

The pinned derivation is in the [local package](../packages/rewaita.nix).

### ripgrep

- **Purpose:** Recursive text search.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Rust and Cargo

- **Purpose:** Rust compiler and package manager.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global development baseline; replaces Rustup for the global default.

### screen

- **Purpose:** Terminal multiplexer.
- **State:** Not selected.

Legacy candidate expected to be removed in favor of tmux.

### Shadowsocks

- **Purpose:** Proxy used by the legacy LXD setup.
- **State:** Retired.

Retired with the legacy LXD proxy rather than migrated; see
[the VPN and proxy decision](DECISIONS.md#scripts-and-privileged-networking).

### ShellCheck (`shellcheck`)

- **Purpose:** Shell script linter.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; bash-language-server in Neovim reports its
diagnostics only when it is on PATH.

### sing-box

- **Purpose:** Selected VPN egress backend, local proxy, application capture and
  explicit whole-host TUN.
- **State:** Active.
- **Owner:** [Proxy module](../modules/programs/sing-box/default.nix).
- **Used by:** [VPNized apps module](../modules/programs/vpnized-apps/default.nix).

The unprivileged backend reads encrypted egress inventory and hostname policy;
credential-free capture runs on demand; `vpn-up` explicitly starts a
supervised root TUN.

### Snap

- **Purpose:** Host-level desktop and container application infrastructure.
- **State:** External.

Host-owned; excluded from normal Home Manager activation.

### sops

- **Purpose:** Encrypted configuration editor.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; also in the development shell, where the secret
gate asks it whether a staged file is encrypted.

### `spotdl`

- **Purpose:** Download Spotify tracks with real metadata.
- **State:** Active.
- **Owner:** [Scripts module](../modules/scripts.nix).
- **Used by:** [download command](../scripts/bin/download.sh).

Backend of `download` for Spotify URLs and the `saved` query, from the
unstable pin; a YouTube URL reaches it only with `--spotify-meta`.

The unstable package input is declared in [flake.nix](../flake.nix).

### Spotify

- **Purpose:** Music application.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### Sublime Merge

- **Purpose:** Git client.
- **State:** Deferred.

Legacy vendor-repository installer; deferred to desktop application review.

### Sublime Text

- **Purpose:** Text editor.
- **State:** Active.
- **Owner:** [Sublime Text module](../modules/programs/sublime-text.nix).

Home Manager installs the program and links the OpenSSL 1.1 shipped in its
own tarball. Nixpkgs' stable `sublime4` build 4200 still needs that library;
build 4205 links OpenSSL 3, at which point the override can be removed. See
the [workaround entry](WORKAROUNDS.md#sublime4) for the details. Without a
license, Sublime Text is available only for evaluation.

### tealdeer

- **Purpose:** `tldr` documentation client.
- **State:** Active.
- **Owner:** [tealdeer module](../modules/programs/tealdeer.nix).

Home Manager module owning the package, replacing the pipx-installed Python
client; native `config.toml` in `configs/tealdeer` is a live-editable symlink.

### tmux

- **Purpose:** Terminal multiplexer.
- **State:** Active.
- **Owner:** [tmux module](../modules/programs/tmux.nix).

Home Manager module owning the package; native configuration in `configs/tmux` is
a live-editable symlink.

### tmux plugins: `sensible`, `resurrect`, `continuum`

- **Purpose:** Sensible defaults, and saving and restoring sessions.
- **State:** Active.
- **Owner:** [tmux module](../modules/programs/tmux.nix).

Nixpkgs `tmuxPlugins`, linked into the tmux config directory under their upstream
names; TPM is retired, so no fetch and no `prefix + I`.

### tmuxinator

- **Purpose:** tmux project launcher referenced by shell configuration.
- **State:** Not selected.

Not selected; the legacy custom launcher helpers were retired as unnecessary.

### Transmission

- **Purpose:** BitTorrent client and command-line tooling.
- **State:** Deferred.

Deferred to desktop application and retained-script review.

### `tree`

- **Purpose:** Directory tree viewer.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `util-linux` namespace tools

- **Purpose:** `nsenter`, `unshare`, `setpriv` and `mount`
  used to enter the capture namespace.
- **State:** Active.
- **Owner:** [VPNized apps module](../modules/programs/vpnized-apps/default.nix).

Private runtime inputs of the VPN command's namespace-entry helper; not host
prerequisites.

### uv

- **Purpose:** Python project, environment and tool manager.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; projects select their own Python versions and
dependencies.

### Vesktop

- **Purpose:** Discord client, including voice.
- **State:** Active.
- **Owner:** [VPNized apps module](../modules/programs/vpnized-apps/default.nix).
- **Used by:** [GNOME module](../modules/desktops/gnome.nix).

Nixpkgs `vesktop` installed by the VPNized apps module with its command,
desktop entry and `discord://` handler routed through the VPN command; settings
in `configs/vesktop` are live-editable; login state stays machine-local; opened by
`<Super>d`.

### Vim

- **Purpose:** Text editor.
- **State:** Not selected.

The package stays undeclared in favor of Neovim. The [Neovim module](../modules/programs/neovim.nix) delivers `configs/vim/.vimrc` as repository material for remote servers.

### Virtualization stack (QEMU/KVM, libvirt, virt-manager, virt-install and UEFI firmware)

- **Purpose:** Run local virtual machines.
- **State:** Active.
- **Owner:** [virtualization bootstrap phase](../scripts/bootstrap/11-virtualization.sh).

The bootstrap phase installs distro packages on x86_64 Debian/Ubuntu, Fedora and Arch. The [VM setup instructions](../README.md#virtual-machines) cover service, network and authorization setup.

### Visual Studio Code

- **Purpose:** Code editor.
- **State:** Active.
- **Owner:** [VS Code module](../modules/programs/vscode.nix).

Home Manager program package; `settings.json` and `keybindings.json` in `configs/vscode`
are live-editable symlinks that VS Code and Settings Sync write through; Settings
Sync installs extensions, and `extensions.list` is their inventory; needs the
`apparmor` phase on Ubuntu.

### wget

- **Purpose:** HTTP and file download tool.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `wl-clipboard`

- **Purpose:** Wayland clipboard commands.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `xclip`

- **Purpose:** X11 clipboard command.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

Home Manager global user tool; the X11 counterpart of `wl-clipboard`, selected
because both the tmux copy chain and Yazi's clipboard plugin choose their tool by
session type.

### xdg-utils

- **Purpose:** Desktop opener used by the retired navigation helper.
- **State:** Deferred.

Deferred until a selected desktop application or script requires it.

### `xsel`

- **Purpose:** Alternative X11 clipboard command.
- **State:** Not selected.

Not selected; it is only the third branch of the tmux copy chain, which falls
through to `xclip` before it and needs nothing when absent.

### Yazi

- **Purpose:** Terminal file manager.
- **State:** Active.
- **Owner:** [Yazi module](../modules/programs/yazi.nix).

Home Manager program package; native TOML configuration in `configs/yazi` is a
live-editable symlink; no Snap.

### Yazi plugin: `clipboard`

- **Purpose:** Put the selected files themselves on the system clipboard.
- **State:** Active.
- **Owner:** [Yazi module](../modules/programs/yazi.nix).

Nixpkgs `yaziPlugins.clipboard`; writes `text/uri-list` through `wl-copy` or
`xclip`, so a GUI application pastes a file rather than a path.

### Yazi plugin: `copy-file-contents`

- **Purpose:** Copy what is inside the selected files, as text.
- **State:** Active.
- **Owner:** [Yazi module](../modules/programs/yazi.nix).

Nixpkgs does not carry this plugin. The [local package](../packages/yazi-copy-file-contents.nix) uses the revision pinned in `configs/yazi/package.toml`.

### yq

- **Purpose:** Command-line YAML, TOML and XML processor, `jq`'s syntax
  against those formats.
- **State:** Active.
- **Owner:** [Home Manager global packages](../modules/packages.nix).

### `yt-dlp`

- **Purpose:** Media downloader.
- **State:** Active.
- **Owner:** [yt-dlp bootstrap phase](../scripts/bootstrap/06-yt-dlp.sh).
- **Used by:** [download command](../scripts/bin/download.sh).

Verified official standalone Linux release in `~/.local/bin`; updates remain
explicit through `yt-dlp -U`; it is the audio and video backend of the
`download` command, which resolves it from `PATH` and falls back to
the path this phase owns.

### zoxide

- **Purpose:** Directory-jumping tool.
- **State:** Active.
- **Owner:** [Zsh module](../modules/programs/zsh.nix).

Home Manager program with declarative Zsh integration.

### Zsh

- **Purpose:** Interactive shell.
- **State:** Active.
- **Owner:** [Zsh module](../modules/programs/zsh.nix).

The [host-deps phase](../scripts/bootstrap/02-host-deps.sh) installs a host Zsh for a stable login path. Home Manager owns the interactive program and generated startup files; the [login-shell phase](../scripts/bootstrap/08-login-shell.sh) selects the host copy.
