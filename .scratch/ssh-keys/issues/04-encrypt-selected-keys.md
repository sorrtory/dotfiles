# 04 — Encrypt and declare the selected private keys

Status: ready-for-agent
Blocked by: 01, 02

## Goal

Bring the keys classified `migrate` under SOPS and declare them so activation
materializes them, without their plaintext ever passing through an agent's
context.

## Work

1. For each selected key, encrypt in place through the `.sops.yaml` creation
   rule: `sops --encrypt --in-place secrets/ssh/<name>`. The rule already covers
   `secrets/`, so the recipient is chosen by the repository rather than by the
   command.
2. Prove the round trip without reading the key: compare `sha256sum` of the
   original against `sops --decrypt <file> | sha256sum`. Equal hashes mean the
   ciphertext is faithful; neither party sees the key.
3. Declare each in `modules/secrets.nix`, giving the mode OpenSSH requires.
4. Confirm the ticket 03 gate accepts every new file under `secrets/`.
5. Scan the built activation closure for each key's content and expect no match,
   the same check the foundation's canary used.

## Constraints

- Never `cat`, `head`, `grep`, or open a private key. No `set -x` in a script
  handling one. Redirect `sops` output to a file, never to a terminal.
- The legacy secrets tree is evidence, not a source to copy wholesale
  (`docs/MIGRATION.md`, "Legacy sources are evidence, not specifications").
- Do not delete the operator's working keys. This ticket adds a reproducible
  copy; retirement is ticket 06 and only after normal use proves the
  replacement.

## Acceptance

- Matching hashes recorded for every migrated key.
- Gate passes; no plaintext in the store.
- The operator's existing SSH access is untouched at the end of this ticket.
