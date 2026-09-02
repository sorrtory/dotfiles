# Dotfiles

Cross-distribution Linux user environment built with Nix flakes and Home Manager. The repository is at its initial migration checkpoint; legacy configuration and secrets have not been imported.

## Bootstrap Nix

The bootstrap dispatcher exposes explicit, repeatable components:

```bash
./scripts/bootstrap.sh status
./scripts/bootstrap.sh install nix
```

With no component names, the dispatcher runs every executable component under `scripts/bootstrap/`; one or more names select specific components. The `nix` component installs official multi-user Nix and enables `nix-command` and flakes; it refuses to run when its status is already satisfied. Open a new login shell after its first successful run.

## Build Home Manager

Build without activation:

```bash
nix flake check
nix build .#homeConfigurations.z.activationPackage
```

Activate the resulting generation only on the staging VM or after explicit host approval:

```bash
./result/activate
```

The current profile targets user `z` on `x86_64-linux`.

## Project guidance

- [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.
- [docs/DECISIONS.md](docs/DECISIONS.md) records ownership and policy.
- [docs/MIGRATION.md](docs/MIGRATION.md) defines migration order and verification.
- [AGENTS.md](AGENTS.md) contains agent operating rules and the staging target.

This repository is intended to become public. Never add plaintext secrets or a private age identity.
