# 05 — Verify the launcher families, and the leaks

Status: needs-triage
Blocked by: 00, 04

## Design gate

The operator selected a shared sing-box backend and namespace TUN instead of
the separate kernel-WireGuard design. The work below is historical planning,
not an implementation instruction. Resolve ticket 00, then rewrite this ticket
around the verified lifecycle and compatibility results before claiming it.

## Goal

Prove the command works for the applications actually installed here, and that
what it tunnels is everything the application sends.

## Work

1. Verify one of each family the operator has, from a session on a machine
   with a desktop:
   - Electron from `/usr/bin`: Obsidian, Spotify, or Code.
   - A snap: Chromium or Firefox.
   - A Flatpak: AyuGram or another installed application.
   - A plain command: `curl`, which is the cheap regression check.
2. For each, confirm the process is in the namespace by inode, comparing
   `/proc/<pid>/ns/net` to `/var/run/netns/<ns>`. A window that opened proves
   nothing about routing.
3. Confirm the external address seen by the application differs from the
   host's. For a browser, a page that reports the address does this directly;
   for others, the process's own connections through `ss -tp` inside the
   namespace.
4. Check for leaks that the address test does not catch: name resolution
   outside the tunnel, and IPv6 escaping while IPv4 is tunneled. Decide
   deliberately what the namespace does with IPv6 when the tunnel carries none
   — routing it nowhere is safer than letting it out untunneled, and either
   way it should be a decision recorded rather than an accident.
5. Note per-family friction as it is found. Snaps and Flatpaks may need their
   own handling to reach the session sockets from inside a private mount
   namespace; that belongs here rather than as a surprise in the code.

## Constraints

- The staging VM has a desktop session but no usable GPU, so applications that
  need one may not start there at all. Verify what can be verified on the VM,
  and be explicit about what only the host can show.
- Privileged commands on the VM have been refused by the sandbox in past
  sessions. Expect to hand some steps to the operator, and write the exact
  command when doing so.

## Acceptance

- Each of the four cases runs, and each is confirmed in the namespace by inode.
- The external address differs from the host's in every case.
- DNS resolves through the tunnel, verified rather than assumed.
- IPv6 behavior is stated and matches what was decided.
