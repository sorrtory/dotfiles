# 03 — Run the payload as the invoking user, in a desktop it recognizes

Status: needs-triage
Blocked by: 00, 01, 02

## Design gate

The operator selected a shared sing-box backend and namespace TUN instead of
the separate kernel-WireGuard design. The work below is historical planning,
not an implementation instruction. Resolve ticket 00, then rewrite this ticket
around the verified lifecycle and compatibility results before claiming it.

## Goal

Make a graphical application inside the namespace behave exactly as it does
outside it, minus the route.

## Work

1. Escalate for setup, then drop back to the invoking user before executing
   anything the user asked for. The payload must never run as root.
2. Capture the invoking user's environment before escalating and restore it
   after dropping back, rather than enumerating variables to preserve. Write it
   somewhere only that user and root can read, and remove it afterwards.
3. Always run the payload in a private mount namespace, with the namespace
   resolver bind-mounted over `/etc/resolv.conf` and over resolved's stub paths
   where they exist. The legacy `-g` did this only on request; it becomes the
   only path.
4. Keep the cgroup2 and securityfs mounts the legacy script performs, or
   demonstrate that a current sandbox no longer needs them and drop them with
   that evidence recorded. This host does not restrict unprivileged user
   namespaces — `kernel.apparmor_restrict_unprivileged_userns` is `0` — so a
   Chromium sandbox should work without `--no-sandbox`, and needing that flag
   is a signal something here is wrong rather than a fix.
5. Fail loudly and specifically when the session sockets the payload will need
   are missing: the Wayland or X socket, the session bus, PipeWire or PulseAudio.

## Why inheritance rather than a list

The legacy script names sixteen variables and invents fallbacks for six
(`WAYLAND_DISPLAY=wayland-0`, `XDG_CURRENT_DESKTOP=ubuntu:GNOME`, and so on).
Every variable it does not name is absent inside, and every fallback is a guess
that is wrong on some machine. The failures that produces are indirect: a theme
that does not load, a portal that does not answer, an input method that is
silently missing. Inheriting the real environment removes the whole class.

The environment belongs to the same user the payload runs as, so passing it
through crosses no privilege boundary. It must not be readable by other users
while it is on disk.

## Acceptance

- A GUI application launched through the command shows its window, plays
  sound, and can open a file dialog through the desktop portal.
- `ps -o user=` for the payload shows the invoking user, not root.
- Its `/proc/<pid>/ns/net` matches the tunnel namespace and not the host's.
- `env` inside the namespace and outside it differ only in variables this
  command deliberately sets.
- No temporary environment file remains afterwards.
