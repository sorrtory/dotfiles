# 05 — `vault lock` closes access and proves it

Status: ready-for-agent

Blocked by: 02, 04

## Goal

`vault lock [path]` ends access to the private vault, finishing on its own when
that is possible and, when it is not, telling the operator exactly what is in
the way before anything risky happens.

## Work

1. Implement graceful locking: ask the processes this command owns to close,
   let their own save dialogs stay interactive, then unmount cleanly and stop
   the decryption process. Complete automatically when all of that succeeds.
2. When something blocks the unmount, identify the blockers that can be
   identified, name them, and explain that forcing may lose unsaved edits or
   interrupt writes in progress. Offer retry after manual closure, cancel, or
   force with an explicit confirmation for that one action.
3. Never escalate on elapsed time. There is no timer and no automatic force.
4. Cancelling leaves the vault unlocked and says so.
5. On success, verify that the mount is gone and the owned decryption process
   has terminated. Report failure of either honestly rather than reporting a
   lock that did not happen.
6. State the guarantee's limit where the operator will see it: locking revokes
   access through the mount, and cannot erase plaintext an application has
   already read or cached elsewhere.
7. Do not kill processes indiscriminately. Only processes this command started
   are owned; unrelated applications may hold loaded text and are reported, not
   terminated.
8. Cover the graceful path, the blocked path and the verification failure in
   the command's test.

## Constraints

- Use what ticket 02 observed about SIGTERM, lazy unmount and stale mounts.
  A lazy unmount alone does not revoke outstanding references, so it is not by
  itself a successful lock.
- Confirmation is per forced action. Nothing in the design discussion counts as
  blanket authorization.
- No sudo, and no host-level mount configuration.

## Acceptance

- With nothing holding the vault, `vault lock` completes unattended, and the
  mount and process are both gone afterwards.
- With a file held open, it names the blocker, offers the three choices, and
  does nothing destructive until force is confirmed for that attempt.
- Cancelling reports the vault as still unlocked, and it really is.
- A lock that cannot be verified exits non-zero and says which check failed.
