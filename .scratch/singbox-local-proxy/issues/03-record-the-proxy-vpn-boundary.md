# 03 — Record the boundary between the proxy and the VPN command

Status: ready-for-agent

## Goal

Two VPN mechanisms are only maintainable if the line between them is written
down. Record it, so the overlap is a decision rather than an accident.

## Work

1. Add to `docs/DECISIONS.md`, under "Scripts and privileged networking", the
   boundary: `sing-box` is the always-on, unprivileged, per-application proxy
   for anything that speaks SOCKS or HTTP; the `vpn` command is whole-app
   tunneling through a network namespace for what cannot. Record that both
   read the same whole-file SOPS WireGuard ciphertext, and that this shared
   source of truth is what keeps the duplication acceptable.
2. Note the consequence in `docs/MIGRATION.md` §5: the ciphertext now has two
   consumers, and the browser path needs no deployment to `/etc/wireguard/`
   and no privilege at all. §5's privileged-deployment requirement applies
   only to the `vpn` command in §7.
3. Record in `docs/DECISIONS.md` that a peer identity is per-device: two
   clients sharing one private key make the server re-pin that peer's endpoint
   to whichever handshook last, so both flap. This is why profiles are
   selected per machine rather than shared.

## Constraints

- Record decisions already made; do not introduce new ones here.
- Keep `CONTEXT.md` vocabulary consistent if either term needs an entry.

## Acceptance

- A reader can determine from `docs/DECISIONS.md` alone which mechanism to
  reach for, and why both exist.
