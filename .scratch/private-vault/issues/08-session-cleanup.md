# 08 — The vault closes at logout and shutdown

Status: ready-for-agent

Blocked by: 05

## Goal

Ending the graphical session ends access to the private vault. The operator
does not have to remember to lock before logging out, and is not nagged about
it either.

## Work

1. Run the lock at the end of the graphical session, so a mounted vault does
   not survive logout, reboot or shutdown.
2. Bind it to the graphical session rather than to the user's services. User
   lingering is enabled here, so user services do not stop at logout and cannot
   be used as the signal.
3. Take the non-interactive path: no retry, cancel or force questions. Those
   belong to an explicit `vault lock` where the operator is present to answer.
4. Leave screen lock and suspend alone. They do not lock the vault.

## Constraints

- Do not inhibit logout or shutdown, and do not add a vault-specific
  confirmation dialog to either. Session shutdown may end processes without
  preserving unsaved edits, and that is the accepted behaviour.
- Abrupt power loss is not promised to leave the encrypted storage in the same
  state ext4 would. Say so where the operator will find it rather than implying
  a guarantee that does not exist.
- Nothing here runs with sudo or touches host session configuration.

## Acceptance

- Logging out of the GNOME VM with the vault mounted leaves no mount and no
  decryption process in the next session.
- Locking the screen and resuming from suspend leave the vault mounted and
  usable, with no prompt.
- Logout and shutdown are no slower and ask nothing extra.
