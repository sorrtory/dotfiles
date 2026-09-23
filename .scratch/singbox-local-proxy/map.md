# sing-box local proxy

This map records the initial local-proxy migration. The namespace launcher
subsequently shipped; the [VPN egress spec](../vpn-egress/spec.md) owns its
future routing and whole-host design. See [spec.md](spec.md) for the original
proxy slice.

## Tickets

- [01: Local proxy service](issues/01-singbox-user-service.md) — resolved;
  initial service shipped and was later extended by the VPN command.
- [02: Firefox and VS Code](issues/02-point-clients-at-the-proxy.md) —
  needs-triage; its Snap-specific plan predates the current Firefox module
  and encrypted PAC, while VS Code already uses the proxy.
- [03: Shared backend boundary](issues/03-record-the-proxy-vpn-boundary.md) — resolved; decisions and glossary updated.
- [04: Legacy retirement](issues/04-retire-the-lxd-proxy.md) — ready-for-agent; blocked by 02 and normal-use verification. Documentation only; the operator reinstalls the host.
- [05: Transport failover](issues/05-transport-failover.md) — wontfix; the
  selectable-egress milestone uses native sing-box entries and manual
  selection. Automatic failover remains deferred.

## Context

- WireGuard ciphertext already exists. Each machine selects its own peer identity.
- The initial service used sing-box 1.13.19 without TUN or host routing
  changes. The installed namespace-capable version is now 1.14.1.
- The VPN prototype followed ticket 01 and verified a namespace-capable
  version before launcher implementation. It shipped in the retired
  `vpn-command` effort; see Git history, and `.scratch/vpn-egress/` for the
  work that continues it.
- The Firefox PAC delivery remains in the separate Firefox effort.
- The current `staging` flake configuration chooses `desktop-ubuntu`, so it
  does not contend with the host's `laptop` peer. Ticket 01 records the
  earlier collision and its then-used evaluation override.
