# Selectable VPN egresses

Deferred development after the vpn-command slice completes. See [spec.md](spec.md).

## Frontier

The first implementation ticket is 03, but it remains blocked by
vpn-command/06. Current defects and recovery verification are fixed in that
effort rather than hidden inside this enhancement.

## Tickets

- [01: Settle the egress design](issues/01-identities.md) — resolved; decisions captured in the spec and tickets 03–08.
- [02: Additional sandboxed applications](issues/02-any-app-launcher.md) — needs-triage; blocked by 05 and an actual second application.
- [03: Egress inventory and compiler](issues/03-profile-inventory.md) — ready-for-agent; blocked by vpn-command/06.
- [04: Authenticated runtime selector](issues/04-manual-egress.md) — ready-for-agent; blocked by 03.
- [05: Per-app and one-off egress selection](issues/05-per-app-profiles.md) — ready-for-agent; blocked by 04.
- [06: Managed system-wide WireGuard](issues/06-system-wide-coexistence.md) — ready-for-agent; blocked by 04.
- [07: Additional native protocol adapters](issues/07-protocol-adapters.md) — needs-info; blocked by 04 and a real server transport.
- [08: Automatic egress strategy](issues/08-automatic-strategy.md) — needs-info; blocked by 07 and normal-use evidence.

## Order

Implement 03 then 04. Tickets 05 and 06 may proceed independently afterward.
Manual alternatives ship before any automatic policy. v2rayN is initially a
declared system-interface egress with externally owned lifecycle, not a protocol
adapter or a managed provider.
