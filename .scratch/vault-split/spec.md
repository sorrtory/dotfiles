# Spec: Split the KeePassXC vault

Status: ready-for-agent

## Why

The recovery vault is the operator's only KeePassXC database. It holds the
private age identity and root credentials next to dozens of everyday web
accounts. That produces two failures:

- Unlocking it in public exposes everything to a shoulder-surfed password.
- Unlocking is expensive, so it stays locked, KeePassXC-Browser cannot save new
  logins, and Firefox's own store quietly becomes a second, divergent vault.
  Accounts get lost in the gap.

A cheap-to-unlock daily vault fixes the second problem; keeping it separate
from the recovery material is what makes cheap unlocking acceptable.

## Decisions

- **Two vaults, both in the recovery repository** (`sorrtory/keepass`, cloned at
  `~/Documents/keepass`). One repository, one sync path.
- **Recovery vault** stays `Passwords.kdbx` with its `Encryption Keys/sops`
  entry, so the recovery app's defaults do not change. Its key is a long
  password only. It must never require a key file: a fresh machine opens it
  with nothing but memory.
- **Daily vault** is a new `Daily.kdbx`, unlocked by a password plus a key file.
- **The recovery vault holds a fixed list, and nothing else:**
  - the age identity
  - the daily vault's key file, as an attachment
  - Google and Yandex: passwords, recovery codes, TOTP secrets
  - GitHub, which recovery authenticates through
  - the Mozilla account
  - bank, root and host credentials

  Anything not on the list goes to the daily vault without judgment. There is
  exactly one place to search for an ordinary account.
- **Key file delivery through sops-nix.** The key file is encrypted into
  `secrets/`, so a machine that has recovered its age identity gets it at
  activation with no manual step. It is no weaker than a copied file: anyone
  holding `~/.config/sops/age/keys.txt` has the laptop's disk anyway, and that
  disk is LUKS-encrypted (measured: `nvme0n1p3` is `crypto_LUKS`).
- **KeePassXC is the only password store.** Firefox saves no logins; its
  existing logins are imported into the daily vault once.
- **Picker hygiene lives in the vault, not in the split.** Every entry carries a
  URL; dead accounts move to an `Archive` group hidden from the browser
  extension; KeePassXC-Browser returns only best-matching credentials.
  Sign-in-with-Google/Yandex accounts get a password-less entry with a note so
  they are not forgotten.

## Scope

In scope: the vault rules, the one-time migration, key file delivery,
KeePassXC under Home Manager, Firefox's password settings, and the canonical
docs that define the recovery vault.

Out of scope:

- The phone. A mobile KeePass client can open the daily vault with a hand-copied
  key file, read-only; that is operator practice, not repository work.
- Moving phone-number logins to TOTP before giving up the smartphone.
- Firefox packaging, profile and extensions, which the
  [`firefox-nix`](../firefox-nix/map.md) effort owns.

## Risks

- **The migration is the data-loss step.** Entries are moved by hand between
  databases. Git history of the recovery repository is the rollback, so commit
  the untouched `Passwords.kdbx` before starting.
- **Recovery must keep working.** A key file on the recovery vault, a moved
  `Encryption Keys/sops` entry, or a renamed database each break fresh-machine
  recovery silently until the day it is needed.
- **KeePassXC's `keepassxc.ini` is not safe to declare wholesale.** The live file
  holds a KeeShare private key. Declared settings replace the file with a
  read-only store link, so nothing machine-private may be carried into Nix.
- **Startup order.** sops-nix renders the key file from a user service; a
  KeePassXC autostarted before it finds no key file.

## Tickets

See [map.md](map.md).
