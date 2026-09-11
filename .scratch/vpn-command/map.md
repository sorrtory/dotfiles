# VPN command

Launch selected apps through the shared sing-box backend, with namespace
isolation capturing TCP and UDP. See [spec.md](spec.md).

## Frontier

[00: Namespace prototype](issues/00-sing-box-namespace-prototype.md) follows
sing-box service ticket 01. Resolve the prototype before implementing the
remaining launcher tickets; their old kernel-WireGuard designs are superseded.

## Tickets

- [00: Namespace prototype](issues/00-sing-box-namespace-prototype.md) — ready-for-agent; blocked by singbox-local-proxy/01.
- [01: Namespace lifecycle](issues/01-namespace-lifecycle.md) — needs-triage; blocked by 00.
- [02: Isolated DNS](issues/02-dns-from-the-tunnel.md) — needs-triage; blocked by 00, 01.
- [03: Payload user and environment](issues/03-run-as-the-user.md) — needs-triage; blocked by 00, 01, 02.
- [04: Refuse untunneled instance handoff](issues/04-refuse-to-lie.md) — needs-triage; blocked by 00, 03.
- [05: Launcher and leak verification](issues/05-verify-the-launcher-families.md) — needs-triage; blocked by 00, 04.
- [06: Package and document](issues/06-package-and-document.md) — needs-triage; blocked by 00, 05.

## Settled boundaries

One backend and exclusive peer identity per machine; no shared-extra client.
No host-wide VPN, no direct fallback, and no application running as root.
The proxy remains available after the last VPN app exits.
The untracked scripts/bin/vpn.sh predates this design and is preserved.
