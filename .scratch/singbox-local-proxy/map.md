# sing-box local proxy

Replace the legacy LXD + shadowsocks proxy with one unprivileged userspace
process exposing SOCKS5 and HTTP on `127.0.0.1:1080`. The spec records the
measured evidence and the settled design decisions; see [spec.md](spec.md).

## Tickets

- [01: sing-box as an unprivileged local proxy service](issues/01-singbox-user-service.md) — ready-for-agent.
- [02: Point Firefox and VS Code at the local proxy](issues/02-point-clients-at-the-proxy.md) — ready-for-agent; blocked by 01.
- [03: Record the boundary between the proxy and the VPN command](issues/03-record-the-proxy-vpn-boundary.md) — ready-for-agent.
- [04: Retire the LXD proxy machinery](issues/04-retire-the-lxd-proxy.md) — ready-for-agent; blocked by 02.
- [05: Transport failover for a blocked protocol](issues/05-transport-failover.md) — needs-info; waiting on which second transport to deploy on the VPS.

## Context

- This effort carries the first real ciphertext into `secrets/`, which
  `modules/secrets.nix` was built for and deliberately left empty awaiting.
- `docs/MIGRATION.md` §5 already specifies whole-file SOPS ciphertext for
  WireGuard; this effort implements the unprivileged consumer of it, and §7's
  `vpn` command will be the privileged one.
- The Firefox snap's confinement denies hidden home paths and the sops runtime
  directory, which is why PAC encryption cannot land here. That work moves to
  [`firefox-nix`](../firefox-nix/map.md).
