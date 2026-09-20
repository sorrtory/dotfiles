# Agent Instructions

A cross-distro Linux user environment based on Nix, Home Manager, and sops-nix.
The current host is Fedora, where this environment is installed and in daily
use; Home Manager is the normal way the operator's own machine is configured.
The repository stays cross-distro, and feature migration from the legacy
configuration is still in progress.

Read these before making architectural changes:

- `CONTEXT.md` — canonical project vocabulary.
- `docs/DECISIONS.md` — stable decisions, ownership boundaries, and security model.
- `docs/MIGRATION.md` — ordered migration plan from the legacy repos.

## Agent skills

### Issue tracker

Issues and specs are version-controlled Markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default five-role triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository. See `docs/agents/domain.md`.

## Staging

`z@192.168.122.21` is a disposable Fedora 44 Workstation VM (libvirt domain
`fedora`, password `z`) running GNOME on Wayland, so it suits both bootstrap and
GNOME checks. `host-deps` and `nix` are verified there; `secret-recovery` is the
operator's and nothing past it has run. See [docs/STAGING.md](docs/STAGING.md)
for the mirroring command, the sudo helper, and what a VM cannot judge.

## Local validation

Run repository checks and builds on the host:

```bash
nix flake check
nix build .#homeConfigurations.z.activationPackage
```

Activate a built generation on the host only after explicit operator approval.

Prefer objective checks driven through the program's own control interface over
reading logs and assuming. Where a program exposes one — mpv's IPC socket is
the worked example — a check can press the actual key binding and read back the
resulting state, which catches things inspection does not: a binding that
parses but never binds, a property no configuration file mentions, a script
that loads but draws nothing.

## Project map

```text
.
├── AGENTS.md
├── CLAUDE.md               # pointer to AGENTS.md
├── CONTEXT.md
├── README.md
├── flake.nix
├── home.nix                # the profile, per-machine options included
├── docs/
│   ├── DECISIONS.md
│   ├── MIGRATION.md
│   ├── SOFTWARE.md
│   ├── STAGING.md
│   └── agents/
├── modules/
│   ├── desktops/            # GNOME; Hyprland if it is ever migrated
│   ├── programs/            # per-program Home Manager modules
│   ├── theme/               # the palette-driven theme core
│   ├── packages.nix         # general user packages
│   ├── scripts.nix          # exposes scripts/bin commands
│   ├── apparmor.nix         # generated userns allowances
│   └── secrets.nix          # sops-nix declarations
├── configs/                 # mutable native configs kept in the repo
├── packages/                # local Nix packages only when nixpkgs is insufficient
├── scripts/
│   ├── bootstrap.sh         # dispatcher for ordered setup phases
│   ├── bootstrap/           # idempotent fresh-machine phases
│   ├── bin/                 # personal script source; may keep .sh suffix here
│   └── repo/                # repository-maintenance shell commands
├── tests/                   # public-interface tests for repository tooling
└── secrets/
    ├── files/               # whole-file SOPS ciphertext
    └── wireguard/           # encrypted WireGuard configs
```

Create a file only when the corresponding responsibility is actually moved.

## Working rules

1. Preserve the intentionally selected behavior baseline; improve or remove legacy behavior deliberately.
2. Prefer small migration commits over broad rewrites.
3. Prefer Nixpkgs packages and ecosystem package sets before writing local packages.
4. Use `mkOutOfStoreSymlink` intentionally for native configs that should remain live-editable.
5. Do not Nix-ify a readable native config merely for aesthetics.
6. Never commit plaintext secrets or leak them into Nix expressions, logs, patches, or the Nix store.
7. Normal Home Manager activation must not unexpectedly invoke `sudo`.
8. The host distro owns low-level system integration; Home Manager owns the user environment.
9. Application login/session state remains machine-local rather than declarative.
10. Before deleting legacy machinery, verify the replacement under normal use.
