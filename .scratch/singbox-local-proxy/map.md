# sing-box local proxy

One sing-box backend per machine supplies the initial local proxy and the
future namespace launcher. See [spec.md](spec.md).

## Tickets

- [01: Local proxy service](issues/01-singbox-user-service.md) — resolved; built, tested and verified on staging, including reboot. Awaiting operator review before commit/host activation.
- [02: Firefox and VS Code](issues/02-point-clients-at-the-proxy.md) — ready-for-agent; blocked by 01.
- [03: Shared backend boundary](issues/03-record-the-proxy-vpn-boundary.md) — resolved; decisions and glossary updated.
- [04: Legacy retirement](issues/04-retire-the-lxd-proxy.md) — ready-for-agent; blocked by 02 and normal-use verification. Documentation only; the operator reinstalls the host.
- [05: Transport failover](issues/05-transport-failover.md) — needs-info; waiting for a second server transport.

## Context

- WireGuard ciphertext already exists. Each machine selects its own peer identity.
- The new service uses pinned sing-box 1.13.19 without TUN or host routing changes.
- [VPN prototype](../vpn-command/issues/00-sing-box-namespace-prototype.md) follows
  ticket 01 and verifies a namespace-capable version before launcher implementation.
- The Firefox PAC delivery remains in the separate Firefox effort.
- Staging uses desktop-ubuntu through an evaluation override; the host's
  running legacy container owns laptop. Ticket 01 records the detected peer
  collision and exact staging activation command. Do not replace the staging
  override with the default generation while that legacy peer is active.
