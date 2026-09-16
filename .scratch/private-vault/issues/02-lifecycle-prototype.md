# 02 — Prototype the gocryptfs and Obsidian lifecycle on the VM

Status: resolved
Type: prototype

Blocked by: None (can start immediately)

## Question

What do gocryptfs and Obsidian actually do at the moments locking depends on?
The spec commits to a lock that completes gracefully, verifies cleanup and
never lies about it, but the behaviour it must verify has not been observed.
Tickets 05, 06 and 08 would otherwise be written against assumptions.

## Work

Answer these on the Ubuntu GNOME VM, with Nixpkgs gocryptfs 2.6.1, and record
what was observed rather than what the manual says:

1. **Daemon lifecycle.** What the process does on SIGTERM when the mount is
   idle, when a file is open, and when a write is in flight. Whether the
   fallback lazy unmount leaves the process alive, and what the exit status
   distinguishes.
2. **Access after unmount.** Whether a file descriptor opened before a lazy
   unmount still reads plaintext afterwards, and how that is detected from
   outside the process.
3. **Stale mounts.** What is left behind after the process dies without
   unmounting, and what it takes to recover into a usable state without
   destroying data.
4. **Obsidian.** Whether a second vault can be opened while an instance runs;
   what first-time registration of a vault inside a mount asks for; whether the
   window closes on request and what unsaved edits do to that; whether Obsidian
   keeps the mount busy after its window is gone.
5. **Timing.** How long a graceful close-and-unmount takes with a realistic
   notes directory, so ticket 05 can judge the operator's waiting experience.

## Constraints

- Throwaway work. Nothing here becomes a module, a packaged command or a
  repository script; the deliverable is the answer.
- Use the VM's own snapshot to reset rather than cleaning up by hand.
- No host activation, and no plaintext test data that would matter if lost.

## Acceptance

- Each numbered question has an answer recorded under `## Answer`, marked as
  observed or as unresolved, with the commands that produced it.
- The answers say plainly which of them constrain the lock design and how.

## Answer

Run against real gocryptfs 2.6.1 on the Ubuntu GNOME VM. Questions 1, 2, 3 and
5 are answered from observation; question 4 cannot be answered there at all,
for a reason that is itself the finding.

### 1. Daemon lifecycle

- **Idle**: SIGTERM unmounts and exits. Mount gone, process gone.
- **With a file open**: SIGTERM still unmounts and exits, and the descriptor
  opened beforehand then fails with `Transport endpoint is not connected`.
  Access really does end.
- **With a write in flight**: SIGTERM during a 400 MiB `dd` aborted it with
  `dd: IO error: Connection aborted`, exit 1. Forcing costs unwritten data,
  which is what `vault lock` warns about, now measured rather than assumed.

### 2. Access after a lazy unmount

The important one, and it constrains the whole lock design. After
`fusermount3 -uz`: the mount is gone from `mountinfo`, **the daemon is still
alive, and a descriptor opened before the unmount still reads plaintext.** Only
SIGTERM to the daemon ended it. A lock that lazily unmounts and reports success
is lying, so forcing does both.

### 3. Stale mounts

After `kill -KILL` on the daemon, `mountinfo` still lists the mount and every
access returns ENOTCONN. `vault open` names it as stale and points at
`vault lock`; `vault lock` clears it. Recovery needs no manual `fusermount`.

### 5. Timing

800 notes, locked in **0.27s**. Locking is not an operation the operator waits
for, so nothing in the interface needs to account for a slow close.

### 4. Obsidian — cannot be judged on the VM

Obsidian never starts there: `GPU process isn't usable. Goodbye.`, preceded by
`MESA-LOADER: failed to open dri: /run/opengl-driver/lib/gbm/dri_gbm.so`.
`--disable-gpu`, `--in-process-gpu`, `--disable-software-rasterizer`,
`LIBGL_ALWAYS_SOFTWARE=1` and `GALLIUM_DRIVER=llvmpipe` all fail the same way.
This is exactly the limit AGENTS.md sets out: the guest has no usable GPU, and
anything needing a real GPU context cannot be judged there.

What the VM did show:

- `~/.config/obsidian/obsidian.json` holds both vaults as separate entries,
  `/home/z/Documents/Knowledge-Database` and `/home/z/Vault/Notes`, the second
  with `open: true`. So the `obsidian://open?path=` URI registers a vault that
  lives inside a mount, with no prompt, and the two collections coexist.
  Obsidian gets far enough to register the vault and then dies on the GPU.
- Obsidian holds no descriptor and no working directory under the mount, so it
  is not among the blockers `vault lock` finds. Locking with it "open"
  succeeded cleanly.

Still unanswered, and answerable only on a machine with a GPU: whether a second
vault can be opened while an instance is already running, and whether the
window closes on request. Ticket 06 shipped without them.

**This also means `<Super>n` cannot be demonstrated end to end on the VM.** It
unlocks the vault and launches Obsidian correctly; Obsidian then dies for
reasons that have nothing to do with the vault.
