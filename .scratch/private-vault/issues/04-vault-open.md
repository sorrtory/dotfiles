# 04 — `vault open` unlocks the vault and shows it

Status: resolved

Blocked by: 03

## Goal

One command from the terminal turns encrypted storage into a browsable
directory: `vault open [path]` prompts for the password, mounts the vault and
opens the mount in Nautilus. This is the first end-to-end slice the operator
can use.

## Work

1. Implement `vault open [path]`, defaulting to `~/Vault` and reusing the path
   rule from ticket 03.
2. Prompt for the password on the terminal with the echo off. Do not persist
   it, do not put it in arguments or the environment where another process can
   read it, and do not retain it after mounting.
3. Recognize a vault that is already mounted and verified, and reuse it without
   asking again. A second invocation must not stack a second mount.
4. Open the mount directory in the file manager once the mount is confirmed
   usable, not merely started.
5. Keep mount and process bookkeeping in the user's runtime directory, and
   check every entry against the real mount and the real process before
   trusting it. It holds no password and survives nothing: it is not a registry.
6. Fail honestly. A wrong password, storage that was never initialized, and a
   stale mount left by a previous session each produce a distinct message, and
   the last of them says what to do next.
7. Extend the command's test with the reuse path, the uninitialized-storage
   refusal and the bookkeeping validation.

## Constraints

- `vault open` never initializes missing storage. That is ticket 03's job, and
  the separation is deliberate.
- No password persistence of any kind, including keyrings and agents.
- No automatic mounting at login or activation. Unlocking is always explicit.

## Acceptance

- On the Ubuntu GNOME VM, `vault open` on initialized storage mounts the vault
  and opens it in Nautilus; a file written there is unreadable in the encrypted
  sibling directory.
- Running `vault open` twice leaves exactly one mount and asks for the password
  once.
- Each failure mode above prints its own message and exits non-zero.
- Evaluation, the secret scan and the repository tests pass.

## Answer

Done. `vault open [--storage DIR] [MOUNT_DIR]` mounts the vault and opens it in
Nautilus, detached so the vault outlives the terminal that unlocked it.

- **The password never passes through this command.** gocryptfs asks for it
  itself, hidden on a terminal and from stdin otherwise, so there is nothing
  here to leak, log or accidentally persist. The graphical prompt in ticket 07
  becomes `-extpass` rather than anything that handles the password here.
- **Reuse** is decided from `/proc/self/mountinfo`, not from the bookkeeping: a
  mount is believed only when the kernel calls it `fuse.gocryptfs`. A second
  open reports the vault as already unlocked and stacks nothing.
- **The runtime record** under `$XDG_RUNTIME_DIR/vault/` holds the daemon pid
  and the storage path, no password, and is rewritten from a fresh `/proc` scan
  on every open. It is removed when the daemon cannot be found, so a stale
  record is never handed to ticket 05.
- **Distinct failures**: storage that is missing or holds no filesystem points
  at `vault init`; a non-empty mount directory is refused before mounting; a
  mount whose daemon is gone is named as stale and sent to `vault lock`; and a
  mount gocryptfs claims to have made but the kernel does not show is reported
  as the failure it is rather than as success.

Verified on the host with real gocryptfs, through `tests/manual/vault.sh`:
plaintext readable through the mount and absent from the storage, a second open
reusing the mount without stacking, the record naming the process that actually
holds the mount, and a wrong password refused. `tests/vault_test.sh` covers
every refusal that needs no real filesystem. All 21 tests and `nix flake check`
pass. No activation.

### Two findings for 05 and 02

Both came out of the mount left behind when this test first ran with a desktop
available, which is worth keeping rather than tidying away:

- **A file manager on the vault is the blocker.** Nautilus held the mount with
  an open file and `fusermount3 -u` refused. This is the blocked-lock case in
  the flesh, and the blocker is the very application `vault open` launches.
- **A lazy unmount does not end access.** `fusermount3 -uz` detached the mount
  and the gocryptfs daemon kept running, still serving the outstanding
  reference. It stopped only on SIGTERM. The spec says this; it is now
  observed. A lock that lazily unmounts and reports success would be lying.

Also observed: gocryptfs daemonizes by re-executing itself as
`.gocryptfs-wrapped -fg -notifypid=PID -- STORAGE MOUNT`, which is what makes
the daemon findable from `/proc` and is how 05 should expect to find it.
