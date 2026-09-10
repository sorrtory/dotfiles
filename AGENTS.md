# Agent Instructions

This repository is being migrated into a cross-distro Linux user environment based on Nix, Home Manager, and sops-nix.

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

You are allowed to test the flow on the local VM.

```bash
ssh z@192.168.122.214
```

the password is 'z'

use ~/Documents/dotfiles/ as a guest repo

### Mirroring the working tree

The host is always the source of truth. The VM mirrors it and never syncs back,
so anything that exists only on the guest is disposable, and every edit, commit,
and test starts on the host. The guest copy is a plain directory rather than a
clone, so Git operations stay on the host.

This single command is the supported way to send the tree. Run it from the
repository root:

```bash
rsync -ai --delete \
  --exclude='.git/' --exclude='.scratch/' --exclude='result' --exclude='result-*' \
  ./ z@192.168.122.214:~/Documents/dotfiles/
```

`-a` preserves modes, timestamps, and symlinks; `-i` reports exactly which files
changed, which is what makes an unexpected transfer visible; and `--delete` is
what makes the guest a mirror instead of a pile of accumulated leftovers. Repeat
the command with `-n` first whenever the delete list matters. Do not add `-z`:
the tree is small text over a local bridge, so compression costs more than the
transfer.

Each exclusion is load-bearing:

- `.git/` keeps history on the host, where all Git operations belong.
- `.scratch/` is host-side coordination material, not part of the flow.
- `result` and `result-*` are guest build outputs pointing into the guest
  `/nix/store`. They cannot come from the host, and without excluding them
  `--delete` removes the very symlink `./result/activate` needs.

`--delete` never removes an excluded path, which is what keeps `result` alive.
The same protection means an excluded directory left by an earlier sync goes
stale rather than disappearing, so remove a leftover guest `.scratch/` by hand
when it is in the way.

Then activate through the normal dispatcher:

```bash
ssh z@192.168.122.214 'cd ~/Documents/dotfiles && ./scripts/bootstrap.sh install home-manager'
```

A non-interactive `ssh` command runs without Nix on `PATH`. Bootstrap phases
load the daemon profile themselves, but repository tooling that calls `nix`
directly does not, so prefix those with
`. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh &&`.

On the host, evaluate and build without activating:

```bash
nix flake check
nix build .#homeConfigurations.z.activationPackage
```

Activate a built generation directly with `./result/activate` only on the
staging VM, or on the host after explicit operator approval.

## Project map

```text
.
├── AGENTS.md
├── CLAUDE.md               # pointer to AGENTS.md
├── CONTEXT.md
├── README.md
├── docs/
│   ├── DECISIONS.md
│   └── MIGRATION.md
├── home/
├── modules/
│   ├── desktops/
│   │   ├── gnome.nix        # eventually: GNOME/dconf configuration
│   │   └── hyprland.nix     # eventually: Hyprland environment/config
│   ├── programs/            # eventually: per-program Home Manager modules
│   ├── packages.nix         # eventually: general user packages
│   ├── scripts.nix          # eventually: expose scripts/bin commands
│   └── secrets.nix          # eventually: sops-nix declarations
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

The `.nix` names shown in the map are destinations, not files that must already exist. During migration, create them only when the corresponding responsibility is actually moved.

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
