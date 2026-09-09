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

The official stable `yt-dlp` binary is an intentional exception: bootstrap installs the verified standalone Linux release under `~/.local/bin`, and `yt-dlp -U` performs explicit updates. Home Manager owns FFmpeg and PATH, but does not install a competing `yt-dlp` package.

Docker is host integration rather than a Home Manager package. Its bootstrap phase uses Docker's official stable convenience installer, previews the installer's package plan, invokes it with explicit privilege, and adds the invoking user to the `docker` group. Membership in that group grants root-level privileges and is therefore a deliberate operator choice. Its explicitly requested uninstall is a full reset: it removes the current user from the group, purges known Docker packages, removes Docker repository configuration, and deletes `/var/lib/docker` and `/var/lib/containerd`, including all local images, containers, volumes, and containerd state.

Sublime Text is a selected evaluation application despite its pinned package depending on OpenSSL 1.1. The exact `openssl-1.1.1w` package is an explicit permitted-insecure exception; using Sublime's vendor package would not remove the exposure because the same runtime is bundled there. Native settings remain live-linked, and a hash-pinned Package Control archive bootstraps the declarative plugin list. Continued use beyond evaluation requires a Sublime Text license.

Anime4K is expected to become a pinned local package rather than vendored shader files. Existing tmux and MPV ecosystem packages should not be repackaged locally.

## Configuration policy

Keep a readable native config when translating it to Nix would reduce clarity. Use `mkOutOfStoreSymlink` intentionally when immediate editability is valuable.

Home Manager should eventually own Zsh, Git, tmux, MPV, Yazi, and intentional GNOME dconf settings. Migration may preserve selected native configuration first and translate it later.

GNOME and Hyprland concerns remain separate. GNOME should use `dconf.settings` where practical; Hyprland may remain native and live-linked if that is clearer.

## Bootstrap policy

This section is the single source of truth for the bootstrap phase
contract. The
[`check-bootstrap-phases.sh`](../scripts/repo/check-bootstrap-phases.sh)
validator is its executable enforcement; other documentation links here rather
than restating the contract.

`scripts/bootstrap.sh` dispatches the ordered phases of the fresh-machine flow. Executable phase files live directly under `scripts/bootstrap/`, use contiguous two-digit `NN-name.sh` prefixes beginning at `01`, and run in lexical order. Renumber phases when inserting or reordering them. The numeric prefix controls order but is omitted from the logical name accepted by the dispatcher. Every executable phase belongs to the default flow; optional operations live outside that set.

A phase supports three commands:

- `status`: read-only and network-free; reports whether the required state is satisfied and includes a version when meaningful.
- `install`: skips successfully when the phase is already satisfied; otherwise it asks no configuration questions, performs only that phase's setup, and may prompt for authentication required to establish that state, including privilege, GitHub, or vault authentication.
- `uninstall`: available only for phases that own safely removable state; it refuses to continue when that state is already fully absent and otherwise removes all recognized complete or partial phase state while preserving unrelated configuration. Ensure-only phases report that they do not support uninstall.

The dispatcher exposes `status`, `install`, and `uninstall`. With no names, `status` inspects every phase and `install` ensures every phase in order. Aggregate status returns 0 when every selected phase is satisfied, 1 when at least one is unsatisfied, and 2 when at least one phase could not be inspected; it still inspects every selected phase. Installation stops at the first failure; rerunning checks earlier phases, skips those already satisfied, and resumes from the first unsatisfied phase. Explicit names preserve caller order. `uninstall` always requires one or more explicit phase names and never defaults to the complete flow.

Each phase enables `set -euo pipefail`, sources `scripts/bootstrap/common/phase.sh`, defines exactly one `check()` and `install()`, and ends with exactly one `phase_main "$@"` entrypoint. A reversible phase additionally defines exactly one `is_uninstalled()` and `uninstall()`; these functions must be provided as a pair. Strict mode makes a failed mutation stop immediately; the common entrypoint verifies this prerequisite at runtime. `check()` returns 0 when satisfied, 1 when unsatisfied, and a value greater than 1 when checking itself fails. The common command contract applies that result before installation and verifies the postcondition afterward. `is_uninstalled()` succeeds only when no recognized complete or partial phase state remains; the common contract similarly guards and verifies supported uninstallation.

Shared implementation lives under `scripts/bootstrap/common/` and is excluded from phase discovery. `phase.sh` owns the phase command contract, `output.sh` prefixes human-facing output with the logical phase name, and `packages.sh` owns host package-manager adapters. `require_commands` only validates; the explicitly mutating `ensure_commands` installs missing same-named packages through APT, DNF, or Pacman and fails clearly on unsupported hosts. Phase files use the common output helpers rather than calling `printf` directly.

The initial numbered flow starts with the ensure-only `host-deps` phase, installs Nix, runs `03-secret-recovery`, and then uses `04-home-manager` to activate the complete secret-bearing profile without privilege. `05-yt-dlp` installs the verified user-owned release binary, and the deliberately privileged `06-docker` phase establishes host Docker integration with an explicit full-reset uninstall. `scripts/bootstrap/01-host-deps.sh` is the authoritative inventory of commands required by later phases; documentation describes that responsibility without duplicating its changing contents. The Home Manager phase records a fingerprint of the flake source it activated, allowing its read-only status check to detect repository changes without evaluating Nix or using the network. Migrate the LXD proxy as its own ticketed Bash task.

## Secrets and authentication

SOPS holds reproducible machine secrets. The recovery vault is the operator's main KeePassXC database; it holds passwords, recovery codes, human/root credentials, and an attachment containing the private age identity. OS or application keyrings hold mutable sessions such as GitHub CLI, Codex, OAuth, and browser logins.

The recovery repository is a fresh private repository containing only the encrypted KeePassXC database and non-sensitive documentation. It must not reuse the legacy secrets repository or its history. GitHub browser authentication and `gh repo clone` make this repository available during recovery; the resulting GitHub CLI credential remains mutable session state and should use a system credential store when available.

The public dotfiles flake exposes a small recovery app whose runtime closure supplies GitHub CLI, KeePassXC CLI, and age after Nix installation but before Home Manager activation. The `secret-recovery` bootstrap phase invokes this app; callers still use the single bootstrap interface rather than running it separately. This avoids a separate secretless Home Manager profile. The app obtains the recovery vault, lets KeePassXC prompt directly for its password, and extracts the age identity attachment without using arguments, environment variables, the clipboard, or logged standard output.

The restored private age identity lives outside Git at `~/.config/sops/age/keys.txt`. Recovery refuses to overwrite an existing identity, writes a mode-`0600` temporary file, verifies its derived public recipient against repository configuration, and moves it into place atomically. Prefer an additional offline recovery copy. Only the public recipient belongs in repository configuration.

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
