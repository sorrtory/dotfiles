# 02 — Prototype the gocryptfs and Obsidian lifecycle on the VM

Status: ready-for-agent
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
