# 08 — The vault closes at logout and shutdown

Status: resolved

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

## Answer

Needed for logout, not for shutdown, and it costs nothing to run.

**What gocryptfs already handles.** SIGTERM makes it unmount and exit; measured
on the host, not assumed: after `kill -TERM`, both the mount and the process
were gone. Shutdown sends SIGTERM to everything, so shutdown was never the
gap.

**What it does not handle.** Logout. Three things line up against it:
`KillUserProcesses` is at its default `no`, lingering is enabled, and a daemon
started from a launcher sits in `user@1000.service/app.slice`, which no session
stop reaches. Read from `/proc/<pid>/cgroup` on the VM. So a vault unlocked
with `<Super>n` stays mounted and decrypted after the operator logs out, until
the machine reboots.

**The mechanism.** A user unit bound to `graphical-session.target`, which is
what actually stops at logout, unlike the user manager. `Type=oneshot` with
`RemainAfterExit=yes` is a unit systemd holds active with no process, so only
`ExecStop` ever does anything. On the VM: `MainPID=0` and `MemoryCurrent` not
set. There is no daemon and nothing to be heavy.

It stops with `vault lock --all --force`: `--force` because nobody is at the
screen to answer a question about blockers, and `--all` because the session may
have unlocked more than the one vault `<Super>n` knows about. `--all` works
from the runtime records, which gained a `mount=` line for the purpose, and
each record is checked against the kernel before it is believed; one naming a
vault nobody mounted is dropped.

Screen lock and suspend are untouched, and nothing inhibits logout or shutdown.

Verified: the unit has no process on the VM; `ExecStop` really does run when a
oneshot `RemainAfterExit` unit is stopped, shown with a transient unit rather
than asserted; and `lock --all --force` locks what a session unlocked and drops
a stale record, covered in `tests/manual/vault.sh`.

Not verified: a real logout. Confirming that end to end needs someone to log
out of the VM's GNOME session, which would also force-unmount the vault the
operator has open there.
