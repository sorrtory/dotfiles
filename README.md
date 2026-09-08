# Dotfiles

Cross-distribution Linux user environment built with Nix flakes and Home Manager. The repository is at its initial migration checkpoint; legacy configuration and secrets have not been imported.

## Bootstrap Nix

The bootstrap dispatcher exposes explicit, repeatable components:

```bash
./scripts/bootstrap.sh status
./scripts/bootstrap.sh install nix
./scripts/bootstrap.sh uninstall nix
```

The dispatcher and every component follow the canonical
[bootstrap policy](docs/DECISIONS.md#bootstrap-policy). The `nix` component
installs official multi-user Nix and enables `nix-command` and flakes. Its
uninstall command follows the official Linux multi-user removal procedure.
Open a new login shell after installation.

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

## Secret safety gate

Enable the repository's tracked pre-commit hook once after cloning:

```bash
git config --local core.hooksPath .githooks
```

The hook validates bootstrap component idempotency and then runs the staged
secret scan. Both checks are also available manually:

```bash
./scripts/repo/check-bootstrap-components.sh --staged
./scripts/repo/check-secrets.sh --staged
```

The scanner uses the gitleaks version pinned by `flake.lock`. It rejects common hardcoded secrets plus private age identities and plaintext WireGuard private keys. SOPS ciphertext and public age recipients are allowed.

Before committing, also inspect high-risk changes deliberately: files under `secrets/`, `.env`-style files, private keys, authentication tokens, decrypted output, and secret values embedded in Nix expressions. The scanner supplements this review; it does not prove that content is safe to publish.

## Project guidance

- [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.
- [docs/DECISIONS.md](docs/DECISIONS.md) records ownership and policy.
- [docs/MIGRATION.md](docs/MIGRATION.md) defines migration order and verification.
- [AGENTS.md](AGENTS.md) contains agent operating rules and the staging target.

This repository is intended to become public. Never add plaintext secrets or a private age identity.
