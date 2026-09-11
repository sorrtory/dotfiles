# 02 — DNS from the tunnel, and never from the host

Status: needs-triage
Blocked by: 00, 01

## Design gate

The operator selected a shared sing-box backend and namespace TUN instead of
the separate kernel-WireGuard design. The work below is historical planning,
not an implementation instruction. Resolve ticket 00, then rewrite this ticket
around the verified lifecycle and compatibility results before claiming it.

## Goal

Give the namespace a resolver that reaches through the tunnel, without
touching any resolver configuration the host uses.

## Work

1. Read `DNS` from the `[Interface]` section of the WireGuard configuration.
   That value is the tunnel operator's own resolver and is reachable through
   the tunnel, which is what makes it the right default.
2. Fall back to a fixed public resolver when the configuration names none, and
   say which was used at that point rather than silently choosing.
3. Write only `/etc/netns/<ns>/resolv.conf`. `ip netns exec` bind-mounts that
   over `/etc/resolv.conf` for processes it starts, which covers ordinary
   programs.
4. Delete the legacy `-d`, `-r`, and `-D` paths along with the host
   `/etc/resolv.conf` backup and restore machinery.
5. Confirm the resolver is routed through the tunnel interface rather than the
   veth, and keep the legacy leak check that proves it, since it is the check
   that would catch a regression here.

## Why the modes go

`-r` copies the host's resolved uplink into the namespace and adds routes so
those nameservers stay reachable over the veth — which means DNS deliberately
leaves outside the tunnel. It exists to work around a resolver that would not
answer otherwise, and it warns about exactly the risk it creates.

The worse part is that it also repoints the host's own `/etc/resolv.conf` and
depends on a backup in `/run` to put it back. If the machine reboots or the
restore path is not reached, the host's DNS configuration is left pointing
somewhere the operator did not choose, long after the command exited. A tool
that runs one application should not be able to do that.

`-d` runs dnsmasq inside the namespace for caching. It is a daemon to start,
supervise, and reap, and the caching it adds is not why this command exists.

## Constraints

- Nothing outside `/etc/netns/<ns>/` may be written.
- A confined application that reads `/etc/resolv.conf` through its own mount
  namespace is ticket 03's problem, not this one — but do not paper over it
  here by touching host paths.

## Acceptance

- Inside the namespace, resolution works and the leak check reports the
  resolver routed through the tunnel interface.
- `/etc/resolv.conf` on the host is byte-identical before and after a run,
  including whether it is a symlink and where it points.
- No dnsmasq process and no `/run/vpn-*` backup files exist at any point.
