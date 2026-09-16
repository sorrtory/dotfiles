# 10 — Locking from the desktop

Status: resolved

Blocked by: None (05 and 07 are done)

## Goal

The operator can lock the private vault from the session, without a terminal,
and the question locking sometimes has to ask is asked where they can answer it.

## Work

1. Give the session a way to invoke `vault lock` on the private vault.
2. Make the blocked case answerable without a terminal. `vault lock` reads
   retry, cancel or force from standard input today, which a desktop launcher
   does not have: there the choice has to be a dialog, listing the blockers the
   same way and defaulting to the safe answer.
3. Keep the terminal behaviour exactly as it is. A dialog is what happens when
   there is no terminal, never a preference imposed on someone who has one.

## Constraints

- Forcing still needs an explicit answer, per attempt. A dialog whose default
  button forces is not an answer.
- No new daemon and no polling.
- The same command and the same guarantees as the terminal path: success still
  means the kernel shows no mount and no daemon is left.

## Acceptance

- Locking from the session closes an idle vault with no interaction.
- With something holding the vault, the blockers are named in a dialog offering
  retry, cancel and force, and cancelling leaves the vault usable.
- Terminal locking is unchanged.

## Answer

Done. A `Lock Vault` desktop entry runs `vault lock` on the private vault, and
the blocked question is now asked wherever the operator can answer it.

- **The question follows the operator.** A terminal gets the same prompt as
  before. A session with no terminal gets a zenity question listing the
  blockers, with Retry as the default button, "Leave unlocked" as cancel and
  escape, and Force as an extra button, which is the only one that is neither
  the default nor what the escape key does. With neither, an answer piped in
  is still honoured and end of input is a cancel, so scripts keep working.
- **The path is declared once.** `dotfiles.privateVault` lives in the vault
  module and both `<Super>n` and the desktop entry read it, rather than the
  literal appearing in two modules that can drift. That is the same mistake
  ticket 01 existed to fix.
- The entry is visible in the overview on purpose, so it can be found and
  given a key of the operator's choosing.

Verified in `tests/manual/vault.sh` against real gocryptfs with a process
holding the mount: a dialog answering Force locks the vault, and a dialog that
cancels leaves the mount and its plaintext intact. Two regressions were caught
there first: a piped answer had stopped working once the dialog was added, and
a failed run left mounts behind.
