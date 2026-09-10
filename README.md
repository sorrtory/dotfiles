# Dotfiles

A cross-distribution Linux user environment built with Nix flakes, Home Manager,
and sops-nix. The host distribution keeps hardware and system integration; this
repository owns the packages, programs, shell, and reproducible secrets of one
user account.

Migration from the legacy configuration is in progress — see
[docs/MIGRATION.md](docs/MIGRATION.md) for what has moved and what has not. The
current profile targets user `z` on `x86_64-linux`.

## Install on a fresh machine

```bash
git clone https://github.com/sorrtory/dotfiles.git ~/Documents/dotfiles
cd ~/Documents/dotfiles
./scripts/bootstrap.sh install
```

That runs every phase below in order and skips the ones already satisfied. Most
phases run unattended; the table says where one stops to ask you for something:

| #   | Phase             | What it does                                                                                                                                                                 | What it asks you for                                                      |
| --- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| 01  | `host-deps`       | Installs the host commands later phases need, using the distro package manager. The [script itself](scripts/bootstrap/01-host-deps.sh) is the authoritative dependency list. | sudo password                                                             |
| 02  | `nix`             | Installs official multi-user Nix and enables `nix-command` and flakes.                                                                                                       | sudo password                                                             |
| 03  | `secret-recovery` | Takes `gh`, `keepassxc-cli`, and `age` from this flake, then restores the age identity to `~/.config/sops/age/keys.txt`.                                                     | **GitHub sign-in** on any device, then your **KeePassXC vault password**  |
| 04  | `home-manager`    | Builds and activates the user environment: packages, program modules, and configs. Never uses privilege.                                                                     | —                                                                         |
| 05  | `yt-dlp`          | Installs the verified official release binary into `~/.local/bin`, so `yt-dlp -U` stays your update path.                                                                    | —                                                                         |
| 06  | `docker`          | The deliberate privileged exception: installs Docker's host components and adds you to the `docker` group.                                                                   | sudo password                                                             |
| 07  | `login-shell`     | Makes the distro-provided Zsh your login shell.                                                                                                                              | sudo password                                                             |

**Then open a new login session.** The new shell, `PATH`, and Docker group
membership only take effect there.

### Running phases individually

```bash
./scripts/bootstrap.sh status            # inspect everything, change nothing
./scripts/bootstrap.sh status docker     # inspect one phase
./scripts/bootstrap.sh install nix       # run one phase
./scripts/bootstrap.sh uninstall docker  # remove one phase's state
```

`nix`, `yt-dlp`, `docker`, and `login-shell` support `uninstall`; the others own
nothing safely removable. Docker's uninstall is a full reset — it deletes all
local images, containers, and volumes. The
[bootstrap policy](docs/DECISIONS.md#bootstrap-policy) is the contract every
phase follows.

### After editing the configuration

Re-activate the user environment through the same dispatcher:

```bash
./scripts/bootstrap.sh install home-manager
```

## Development

Enable the tracked pre-commit hook once after cloning — it is required:

```bash
git config --local core.hooksPath .githooks
```

The hook validates bootstrap phase structure and scans staged changes for
secrets. Both checks also run on demand:

```bash
./scripts/repo/check-bootstrap-phases.sh --staged
./scripts/repo/check-secrets.sh --staged
```

Run the test suite for the repository tooling:

```bash
for test in tests/*.sh; do "$test"; done
```

Evaluate and build the user environment without activating it:

```bash
nix flake check
nix build .#homeConfigurations.z.activationPackage
```

The scanner uses the gitleaks version pinned by `flake.lock`. It rejects common
hardcoded secrets, private age identities, and plaintext WireGuard private keys,
while allowing SOPS ciphertext and public age recipients. It supplements
deliberate review of high-risk changes — files under `secrets/`, `.env`-style
files, private keys, tokens, decrypted output, and secret values inside Nix
expressions — it does not prove content is safe to publish.

## Project guidance

- [CONTEXT.md](CONTEXT.md) defines canonical vocabulary.
- [docs/DECISIONS.md](docs/DECISIONS.md) records ownership and policy.
- [docs/MIGRATION.md](docs/MIGRATION.md) defines migration order and verification.
- [docs/SOFTWARE.md](docs/SOFTWARE.md) maps software to its installation mechanism.
- [AGENTS.md](AGENTS.md) contains agent operating rules and the staging target.

This repository is intended to become public. Never add plaintext secrets or a
private age identity.
