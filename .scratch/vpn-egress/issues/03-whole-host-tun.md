# 03 — Whole-host tunnel follows the active egress

Status: ready-for-agent

Blocked by: 02

## Goal

Replace the `wg-quick` whole-host tunnel with a credential-free sing-box TUN
that forwards to the backend, so `vpn-up` works on every protocol and follows
whatever egress is selected.

## Work

1. Write a static TUN configuration into the Nix store. It holds no secrets:
   a `tun` inbound, one SOCKS outbound to the backend on loopback,
   `route.final` pointing at it, and DNS forwarded to the backend. Nothing is
   generated at runtime.
2. `vpn-up` starts it as a transient system unit through
   `sudo systemd-run`; `vpn-down` stops that unit. One sudo prompt, journal
   logs, no orphan root process.
3. Exclude private and link-local ranges from the tunnel's routes, which keeps
   the LAN and the libvirt bridge — and so the staging VM — reachable.
4. Keep `strict_route` off. With it on, the backend's interface-bound sockets
   are redirected back through sing-box and the tunnel loops.
5. Delete the `wg-quick` path: the `vpn-up`/`vpn-down` aliases' identity
   handover, the runtime marker file, the keyless backend restart bound to an
   interface, the generator's interface argument, `secrets/wireguard/` and the
   `wireguard-tools` package if nothing else uses it.

## Constraints

- The privileged process never holds a credential. Only the unprivileged
  backend does.
- The TUN has no direct outbound and no fallback. While the backend restarts,
  traffic must fail, not leak.
- The backend keeps `route.auto_detect_interface` from ticket 01. That is what
  keeps its own traffic to the VPN server out of the TUN.
- Home Manager still creates no host interface and runs no sudo during
  activation.

## Documentation

Rewrite the `docs/DECISIONS.md` statements that the whole-host tunnel is
`wg-quick` on the machine's identity, that the backend hands the identity over
while it is up, and that `wireguard-tools` is needed for it. Record the new
shape: an unprivileged backend that owns the credentials, and a privileged,
credential-free TUN that forwards to it.

## Acceptance

- [ ] With the tunnel up, ordinary host traffic exits through the active
      egress, and `vpn-egress use` changes it without restarting the tunnel.
- [ ] With the backend stopped, host traffic fails; nothing reaches the
      internet directly. Verified on staging, not assumed.
- [ ] LAN hosts and the staging VM stay reachable while the tunnel is up.
- [ ] `vpn-down` restores host routes and the resolver to their prior state;
      repeated `vpn-up`/`vpn-down` is idempotent or fails with actionable
      state.
- [ ] Vesktop voice still works on the host with the tunnel up, double
      tunnelling included.
