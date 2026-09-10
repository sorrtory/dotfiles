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

The public dotfiles flake exposes a small app invoked by `03-secret-recovery`, immediately after `02-nix`. It supplies `gh`, `keepassxc-cli`, and age; performs GitHub browser authentication when needed; clones the recovery repository; prompts for the vault password through KeePassXC; and restores `~/.config/sops/age/keys.txt` without exposing the identity through the clipboard, command arguments, environment variables, or logged output. It refuses overwrites, uses mode `0600`, verifies the derived public recipient, and installs the file atomically.

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

Recreate selected WireGuard configurations as whole-file SOPS ciphertext. Keep decryption user-owned and deployment to `/etc/wireguard/` explicit and privileged.

### 6. VPN command

Specify, ticket, and rewrite the VPN command. It must create and clean privileged network state while running the requested payload as the invoking user. Package the separate Bash source through `writeShellApplication` and expose `vpn` in the user environment.

### 7. MPV and Anime4K

Replace absolute links and manually cloned plugins with Nixpkgs MPV scripts where available. Package or pin missing dependencies, including Anime4K, and retain readable native MPV configuration when it remains clearer.

### 8. GNOME

Specify and ticket intentional GNOME migration. Capture the current dconf state as evidence, retain deliberate preferences, and omit incidental runtime keys.

## Additional candidates

Reassess remaining candidates after the core milestone or when dependency analysis promotes one. Likely candidates include native Neovim and Kitty configs, Hyprland and Wofi, tmux configuration, Yazi configuration/plugins, selected helper scripts, and reviewed desktop applications.

Use `mkOutOfStoreSymlink` only where live editing is intentional. Do not translate a readable native format merely for aesthetics.

## Legacy retirement

Mine the legacy manager, link script, installer, package list, secrets-fetch logic, and manually maintained plugin checkouts for selected requirements. Archive or delete each only after its replacement is verified. Do not recreate generic legacy provisioning inside Nix.

## Fresh-machine flow

The intended flow is:

1. clone the public dotfiles repository
2. run `scripts/bootstrap.sh install`
3. let `01-host-deps` establish bootstrap prerequisites and `02-nix` install Nix
4. authenticate GitHub when `03-secret-recovery` invokes the flake recovery app and clones the private recovery repository
5. enter the main KeePassXC vault password so the phase can restore and verify the private age identity
6. let `04-home-manager` build and activate the normal profile with sops-nix secrets available
7. let the final `login-shell` phase select the host-owned Zsh
8. open a new login shell
9. run explicit privileged host setup where required
10. authenticate any remaining mutable sessions once on that machine

The repository currently targets the `z` user on `x86_64-linux`; broader host/user parameterization is a later migration decision.
