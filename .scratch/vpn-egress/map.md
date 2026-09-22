# Selectable VPN egresses

Make the backend's way out a selectable egress instead of the machine's single
WireGuard identity: an encrypted inventory of sing-box entries, a switch
command, and a whole-host tunnel that follows the selection on any protocol.
See [spec.md](spec.md).

Supersedes `.scratch/vpn-followups/` and absorbs the remainder of
`.scratch/vpn-command/`, both retired in the commit that created this
directory. Their text is in Git history.

## Frontier

[01: Compile the backend from an encrypted egress inventory](issues/01-egress-inventory.md).
Tickets 05 and 06 are independent defects and may be taken at any time.

## Tickets

- [01: Compile the backend from an encrypted egress inventory](issues/01-egress-inventory.md) — ready-for-agent.
- [02: Switch egress at runtime with `vpn-egress`](issues/02-runtime-selection.md) — ready-for-agent; blocked by 01.
- [03: Whole-host tunnel follows the active egress](issues/03-whole-host-tun.md) — ready-for-agent; blocked by 02.
- [04: Add a real VLESS or Hysteria2 egress](issues/04-native-protocol-egress.md) — needs-info; blocked by 01.
- [05: Make AppArmor install and removal failure-recoverable](issues/05-apparmor-recovery.md) — ready-for-agent; P2; independent.
- [06: Accept relative executable paths in vpn](issues/06-relative-executables.md) — ready-for-agent; P2; independent.
- [07: Evidence for network change and suspend-to-RAM](issues/07-everyday-recovery-evidence.md) — ready-for-human; blocked by 03.
- [08: Retire the legacy VPN material](issues/08-retire-legacy-vpn-material.md) — ready-for-human; blocked by 07.

## Order

01, 02, 03 in sequence: each leaves a working machine, and 01 alone is already
testable because it changes the source of the tunnel and nothing else. 04 may
follow 01 whenever a real server exists, and is worth doing before 03 if one
does. 05 and 06 are unrelated to the egress work and need no gate. 07 and 08
are operator gates that close the effort.

## Context

- Design settled in a grilling session: egresses are not bound to devices, one
  egress is active at a time, traffic is split by entry point before it reaches
  the backend, and switching is a backend restart rather than a live selector.
- Verified during that session, and relied on by the tickets: sing-box 1.14.1
  accepts `//` comments but rejects unknown fields, all six WireGuard endpoints
  are IP literals, unprivileged `SO_BINDTODEVICE` has been allowed since Linux
  5.7, and a systemd user service cannot hold `CAP_NET_ADMIN`.
- `vpn-command/07` (concurrent owners of the VPN identity) is resolved, not
  carried over: commit 8dbbc20 replaced the refusal with the identity handover,
  so a backend started by capture during `vpn-up` comes back keyless and bound
  to the interface. Ticket 03 removes the situation entirely.
- Deferred work — per-app egress pinning, automatic selection, further
  sandboxed applications — is recorded in the spec rather than carried as
  tickets.
