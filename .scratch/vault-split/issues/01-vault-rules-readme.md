# 01 — Write the vault rules in the recovery repository

Status: ready-for-agent

## Goal

Put the rules where the vaults live, so choosing a vault never needs this
repository or memory.

## Work

1. Add `README.md` to `~/Documents/keepass` (`sorrtory/keepass`, private).
2. Keep it short: which file is which, the fixed list, and the rules. Roughly:

   ```markdown
   # keepass

   - `Passwords.kdbx` — recovery vault. Long password, no key file. Only:
     - age identity (`Encryption Keys/sops`)
     - `Daily.kdbx` key file
     - Google, Yandex: password, recovery codes, TOTP
     - GitHub
     - Mozilla account
     - bank, root and host credentials
   - `Daily.kdbx` — everything else. Password + key file.

   Rules:

   - Not on the list → `Daily.kdbx`.
   - Dead account → `Archive` group. Never delete.
   - Every entry has a URL. Sign-in-with-Google accounts get an entry too:
     URL, no password, note `OAuth: Google`.
   - Never commit the key file.
   ```

## Constraints

- No secrets, entry titles beyond the list, or recovery instructions that
  belong in the dotfiles docs.
- Do not touch `Passwords.kdbx` in this ticket.

## Acceptance

- The README is committed and pushed, and fits on one screen.
