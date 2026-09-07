# Decision Log

## Platform and ownership

Use Nix flakes, Home Manager, sops-nix, and age on generic Linux. Do not introduce chezmoi.

The host environment owns the kernel, hardware integration, display manager, NetworkManager, PipeWire, distro-coupled services, privileged networking prerequisites, and other low-level integration. The user environment owns user packages, development tools, shell and application configuration, personal scripts, GNOME preferences, and reproducible user secrets.

Normal Home Manager activation must not invoke `sudo`. Root-owned files and system integration use explicit bootstrap or deployment actions.

## Repository organization

Consolidate active configs, selected personal scripts, and public-safe SOPS material in this repository. Do not merge legacy repository histories.

- `modules/desktops/` owns GNOME and Hyprland concerns.
- `modules/programs/` owns application-specific configuration and the corresponding package.
- `modules/packages.nix` owns standalone global user tools.
- `configs/` holds readable native configs that should remain live-editable.
- `packages/` is reserved for software missing or inconvenient in Nixpkgs.
- `scripts/bin/` holds selected user-facing script sources.
- `scripts/repo/` holds repository-maintenance shell commands that are not installed into the user environment.
- `secrets/` may contain only public-safe secret material.

Create files only when their responsibility is migrated. Do not pre-create the project map.

## Package policy

Use the legacy `install.sh` and `install.conf` as the package baseline, not as an unconditional package list. Prefer Nixpkgs, then ecosystem package sets, before writing local packages.

A program module owns the package it configures. Standalone tools belong in `modules/packages.nix`; avoid declaring the same package in both places.

The initial global development baseline is Go through `pkgs.go`, Rust and Cargo, JDK 21, GCC/G++, Make, and `pkg-config`. JDK 21 includes the Java runtime, so a separate JRE is unnecessary. The exact versions are pinned by `flake.lock`; project development shells override them only when a project needs another version or dependency set.

Do not design around `cargo install` or `go install`. Prefer a Nix package or a project development environment.

The official stable `yt-dlp` binary is an intentional exception: a later bootstrap component installs it under `~/.local/bin`, and `yt-dlp -U` performs explicit updates. Home Manager owns its stable dependencies and PATH, but does not install a competing `yt-dlp` package.

Anime4K is expected to become a pinned local package rather than vendored shader files. Existing tmux and MPV ecosystem packages should not be repackaged locally.

## Configuration policy

Keep a readable native config when translating it to Nix would reduce clarity. Use `mkOutOfStoreSymlink` intentionally when immediate editability is valuable.

Home Manager should eventually own Zsh, Git, tmux, MPV, Yazi, and intentional GNOME dconf settings. Migration may preserve selected native configuration first and translate it later.

GNOME and Hyprland concerns remain separate. GNOME should use `dconf.settings` where practical; Hyprland may remain native and live-linked if that is clearer.

## Bootstrap policy

`scripts/bootstrap.sh` is a small dispatcher, not a universal installer. A component under `scripts/bootstrap/` supports two commands:

- `status`: read-only and network-free; reports whether the required state is satisfied and includes a version when meaningful.
- `install`: first runs `status` and refuses to continue when the required state is already satisfied; otherwise it asks no configuration questions, performs only that component's setup, and may prompt for authentication when privilege is required.

The dispatcher exposes `status` and `install` commands for one, several, or—when no names are given—all executable components discovered under `scripts/bootstrap/`. It does not maintain a separate component list. Non-executable `scripts/bootstrap/common.sh` owns the shared component command contract and small generic helpers.

The initial checkpoint contains only the Nix bootstrap component. Add `yt-dlp` during package migration and migrate the LXD proxy as its own ticketed Bash task.

## Secrets and authentication

SOPS holds reproducible machine secrets. KeePassXC holds passwords, recovery codes, human/root credentials, and the private age identity. OS or application keyrings hold mutable sessions such as GitHub CLI, Codex, OAuth, and browser logins.

The private age identity lives outside Git, expected at `~/.config/sops/age/keys.txt`, with recovery copies in KeePassXC and preferably offline. Only its public recipient belongs in repository configuration.

WireGuard configurations are whole-file SOPS ciphertext. Decryption may be user-owned, but deployment to `/etc/wireguard/` is an explicit privileged action.

Everything committed under `secrets/` must already be public-safe. Never copy a legacy secrets tree or expose plaintext through Nix expressions, logs, patches, or the Nix store.

## Scripts and privileged networking

Source scripts may keep `.sh`; Home Manager may expose commands without the suffix. Only the VPN command is selected for the core milestone. Other utilities are additional candidates, and browser userscripts belong in the separate `monkeys` repository.

Keep VPN Bash source under `scripts/bin/` and package it with `writeShellApplication` by reading the separate source. The explicit command may request `sudo`, but payload commands inside the network namespace must run as the invoking user. Rewrite it in its own specified and ticketed slice after the WireGuard foundation exists.

## Migration and review

Legacy sources are evidence, not specifications. Select a behavior baseline, then deliberately retain, improve, replace, or remove each migration candidate. Prefer small coherent slices and do not combine unrelated relocation, package-manager, configuration-language, and behavior changes.

Use the Matt flow per slice: `/grill-with-docs` then `/implement` for small work; add `/to-spec` and `/to-tickets` for substantial work.

The working repository is authoritative. The staging VM is disposable and may be activated after a successful build. Host evaluation and non-activating builds are allowed; host activation requires explicit approval.

The documented staging credential is intentionally public test data, not a secret. It must never be reused by a trusted machine or service.

Every resulting configuration receives operator review before commit. Subjective behavior also requires normal-use review. Automated review supplements these checks rather than replacing them.

Run a local mechanical secret scan on every staged change. Do not publish the repository before the dedicated public-safety gate passes.

Keep `.scratch/` only while coordination is active. Fold durable knowledge into canonical documentation and remove completed scratch material; Git history remains the record.
