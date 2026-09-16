# 05 — `vault lock` closes access and proves it

Status: resolved

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

## Answer

Done. `vault lock [--force] PATH` ends access and proves it.

- **Graceful first.** A clean `fusermount3 -u`; gocryptfs exits by itself once
  its mount is gone. Nothing is asked of the operator when nothing is wrong.
- **Blocked is reported, not guessed at.** Blockers come from `/proc`: a
  working directory, root, executable or open descriptor under the mount. Each
  is printed with its pid and command, followed by what forcing costs. A
  process that merely read a file and let go is not listed, and cannot be.
- **Retry, cancel or force**, answered per attempt, with no timer and no
  automatic escalation. Cancelling leaves the vault unlocked and says so.
- **Forcing is lazy unmount plus SIGTERM to the daemon**, which is the pair the
  ticket-04 accident showed to be necessary: the lazy unmount alone left the
  daemon serving the holder's open file. The daemon is asked to stop and given
  five seconds; it is never SIGKILLed on a timer. If it will not go,
  verification says so rather than reporting a lock that did not happen.
- **Success means the kernel shows no mount and the daemon is gone.** Both are
  checked. The closing line says plainly that this ends access through the
  mount and cannot unread what a program already loaded.
- `--force` skips the question for a session ending with nobody there to
  answer, which is what ticket 08 needs.

Verified on the host in `tests/manual/vault.sh` against real gocryptfs: a clean
lock leaves no mount, no daemon and no runtime record; locking an already
locked vault is not an error; with a process holding the mount the blocker is
named, cancelling leaves the vault usable with its plaintext intact, and
forcing ends access anyway. `tests/vault_test.sh` covers the unmounted case,
the stale record and the argument errors. 21 tests and `nix flake check` pass.
