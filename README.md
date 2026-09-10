# Dotfiles

Cross-distribution Linux user environment built with Nix flakes and Home Manager. The repository is at its initial migration checkpoint; legacy configuration and secrets have not been imported.

## Bootstrap

The bootstrap dispatcher checks or installs the ordered fresh-machine phases:

```bash
./scripts/bootstrap.sh status
./scripts/bootstrap.sh install
./scripts/bootstrap.sh install nix
./scripts/bootstrap.sh install secret-recovery
./scripts/bootstrap.sh install home-manager
./scripts/bootstrap.sh install yt-dlp
./scripts/bootstrap.sh install docker
./scripts/bootstrap.sh uninstall yt-dlp
./scripts/bootstrap.sh uninstall docker
./scripts/bootstrap.sh uninstall nix
```

With no phase names, `status` inspects the complete flow and `install` skips
satisfied phases before continuing in order. The ensure-only `host-deps` phase
installs the host commands required by later phases; its script is the
[authoritative dependency inventory](scripts/bootstrap/01-host-deps.sh).
The following `nix` phase installs official multi-user Nix and enables
`nix-command` and flakes. Its explicit uninstall command follows the official
Linux multi-user removal procedure, while `host-deps` does not support unsafe
package removal. The following `secret-recovery` phase uses the public flake to
supply GitHub CLI, KeePassXC CLI, and age; it then authenticates GitHub when
needed, obtains the private recovery vault, and restores the verified dotfiles
age identity. The final `home-manager` phase builds and activates the repository
configuration without privilege, recording which source state it activated so
later bootstrap runs can detect changes. The `yt-dlp` phase installs a verified
official release binary under `~/.local/bin`. The `docker` phase is the
deliberately privileged exception: it installs Docker's host components and
adds the invoking user to the `docker` group. Its explicit uninstall removes
the packages, repository configuration, group membership, and all local Docker
data, including images, containers, and volumes. See the canonical
[bootstrap policy](docs/DECISIONS.md#bootstrap-policy) for the phase contract.
The final `login-shell` phase selects the distro-provided Zsh for the account.
Open a new login session after bootstrap completes so the new shell, PATH, and
Docker group membership are all current.

The recovery app is also directly available for focused recovery or diagnosis:

```bash
nix run .#recover-age-identity
```

It reads the `keys.txt` attachment from the `Encryption Keys/sops` entry in
`Passwords.kdbx`, obtained from the private `sorrtory/keepass` repository. It
installs the identity at `~/.config/sops/age/keys.txt`, refuses to replace an
existing mismatched identity, and never accepts the vault password through an
argument or environment variable.

## Home Manager

Normal fresh-machine activation is handled by `04-home-manager` through the
bootstrap dispatcher. For local evaluation or focused diagnosis, build without
activation:

```bash
nix flake check
nix build .#homeConfigurations.z.activationPackage
```

Activate the resulting generation directly only on the staging VM or after
explicit host approval:

```bash
./result/activate
```

The current profile targets user `z` on `x86_64-linux`.

## Secret safety gate

Enable the repository's tracked pre-commit hook once after cloning:

```bash
git config --local core.hooksPath .githooks
```

The hook validates bootstrap phase structure and then runs the staged
secret scan. Both checks are also available manually:

```bash
./scripts/repo/check-bootstrap-phases.sh --staged
./scripts/repo/check-secrets.sh --staged
```

The scanner uses the gitleaks version pinned by `flake.lock`. It rejects common hardcoded secrets plus private age identities and plaintext WireGuard private keys. SOPS ciphertext and public age recipients are allowed.

Before committing, also inspect high-risk changes deliberately: files under `secrets/`, `.env`-style files, private keys, authentication tokens, decrypted output, and secret values embedded in Nix expressions. The scanner supplements this review; it does not prove that content is safe to publish.

## Project guidance

- [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.
- [docs/DECISIONS.md](docs/DECISIONS.md) records ownership and policy.
- [docs/MIGRATION.md](docs/MIGRATION.md) defines migration order and verification.
- [docs/SOFTWARE.md](docs/SOFTWARE.md) maps software to its installation mechanism.
- [AGENTS.md](AGENTS.md) contains agent operating rules and the staging target.

This repository is intended to become public. Never add plaintext secrets or a private age identity.
