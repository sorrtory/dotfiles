# 02 — Create the daily vault and move the data

Status: ready-for-human
Blocked by: 01

## Goal

End with `Passwords.kdbx` holding only the fixed list and `Daily.kdbx` holding
every other account, including Firefox's saved logins, with nothing lost.

## Work

1. Confirm `Passwords.kdbx` is committed unchanged; that commit is the rollback.
2. Create `Daily.kdbx` in `~/Documents/keepass` with a password and a new
   KeePassXC key file (`Daily.keyx`). Keep the key file outside the repository.
3. Attach `Daily.keyx` to an entry in `Passwords.kdbx`.
4. Move every entry not on the fixed list from `Passwords.kdbx` to `Daily.kdbx`.
5. Import Firefox's logins: export from `about:logins` to CSV, import into
   `Daily.kdbx`, merge duplicates, then shred the CSV. Leave Firefox's copies in
   place until ticket 05.
6. Clean the daily vault: move dead accounts to an `Archive` group with browser
   integration hidden, fill missing URLs (Database Reports lists them), add
   password-less entries for OAuth-only accounts.
7. Change the `Passwords.kdbx` password to a long one if it is not already.
8. Commit both databases.

## Constraints

- `Passwords.kdbx` keeps its name, its path and the `Encryption Keys/sops`
  entry, and gets no key file. The recovery app's `RECOVERY_DATABASE` and
  `RECOVERY_ENTRY` defaults must stay correct.
- The key file never enters either repository in plaintext.

## Acceptance

- Entries before the move equal entries after, across both databases plus the
  imported Firefox logins, minus merged duplicates.
- `Passwords.kdbx` contains only the fixed list.
- `keepassxc-cli attachment-export` of the age identity from
  `Encryption Keys/sops` still works with the password alone.
- `Daily.kdbx` opens with the password plus the attached key file.
