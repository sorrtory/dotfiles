# 04 — Refuse when the application is already running outside the tunnel

Status: ready-for-agent
Blocked by: 03

## Goal

Make it impossible to end up with an application that appears tunneled and is
not.

## The mechanism being defended against

Electron and Chromium applications keep a `SingletonLock` and
`SingletonSocket` in their profile directory. A second launch connects to that
socket, hands over the arguments, and exits; the running process opens the
window. Inside the namespace that means the command starts a process which
immediately exits, a window appears from the process outside, and the user
believes the application is on the tunnel. Nothing errors.

`snap-confine` reuses a per-snap mount namespace and joins the running
instance. Flatpak shares instances through its session services. The shape is
the same for all three: success and silent no-op are indistinguishable.

## Work

1. Before launching, determine whether the payload would join an existing
   instance, and exit non-zero with a message naming what is running and how
   to proceed if so.
2. Cover the three families the operator uses, plus the generic case:
   - a matching process already running as this user, by executable path where
     one can be resolved and by name otherwise;
   - Electron and Chromium profiles: a live `SingletonLock` under
     `~/.config/<app>/`, which is a symlink whose target names the holding
     host and pid;
   - snaps, via the running instance rather than the snap being installed;
   - Flatpak, via `flatpak ps` and the application id, since the payload there
     is `flatpak run <id>` and the process name says nothing.
3. Where a family cannot be checked reliably, say so in the message rather than
   passing silently. An honest "cannot tell" is worth more than a check that
   quietly fails open.
4. Verify each check the only way that means anything: start the application
   normally, then run it through the command, and confirm the refusal.
5. Verify the inverse too: with nothing running, each family launches and lands
   in the namespace, confirmed through `/proc/<pid>/ns/net`.

## Constraints

- Do not kill or restart the running instance. The user's session is theirs;
  the command reports and stops.
- Do not offer a `--force` that skips the check. The whole point is that the
  silent failure cannot be reached by accident, and a flag whose only purpose
  is to reach it undoes that. If the operator wants a second instance, ticket
  05 covers the profile question.

## Acceptance

- With Obsidian, Spotify, or Code already open, the command exits non-zero and
  names the running instance.
- The same for a running snap and a running Flatpak application.
- With nothing running, each launches and is confirmed inside the namespace.
- No path exists that launches an application which ends up outside the tunnel
  without the command having said so.
