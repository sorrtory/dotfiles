# Spec: sing-box local proxy

Status: ready-for-agent

## Purpose

Replace the legacy LXD/Shadowsocks proxy with one unprivileged sing-box backend
per machine. The local proxy is the first entry point; a later network namespace
will let `vpn <app>` use the same backend for whole-application TCP and UDP.
See `docs/DECISIONS.md` for the shared backend and identity decisions.

## Settled design

- One backend per machine, with an exclusive per-machine WireGuard identity.
  Both local entry points will share it; restarting the backend interrupts both.
- Whole-file SOPS WireGuard ciphertext already exists. Reuse it, generating
  runtime JSON without putting credentials in arguments, environment variables,
  diagnostics, or the Nix store.
- Run a systemd user service with a mixed SOCKS/HTTP listener on
  `127.0.0.1:1080` and HTTP on `127.0.0.1:3128`, matching the existing
  `proxy-on` shell function.
- Use a userspace WireGuard endpoint. This first slice creates no TUN, changes
  no host routes or resolver configuration, and needs no network privilege.
- Proxied destinations and their DNS use the tunnel, with no direct fallback.
  Host DNS may resolve the WireGuard endpoint itself when it is a hostname.
  If the profile names no DNS server, use 1.1.1.1 through the tunnel.
- Enable linger through an explicit bootstrap phase so the service runs before
  login and after logout. Normal Home Manager activation remains unprivileged.
- Start with pinned sing-box 1.13.19. Built-in namespace support needs 1.14+;
  upgrading and verifying it belongs to the VPN prototype, not this service.
- Keep legacy host machinery until normal-use review. Retirement ticket 04 is
  documentation only; the operator retires the old installation by reinstalling.

## Scope

Ticket 01 establishes the backend, profile-to-config generator, runtime secret
handling, linger, tests, and staging verification. Ticket 02 selects proxy use
in Firefox and VS Code. Ticket 03 records the shared-backend boundary. Ticket
04 records retirement after client verification.

Whole-application capture, Discord voice/UDP, namespace DNS isolation, and
Snap/Flatpak launch behavior belong to the VPN effort. An ordinary proxy
setting does not establish whole-application coverage.

Transport failover stays deferred: there is no second server transport to
exercise. Do not add an untested selector or a direct fallback.

## Profile ownership

`dotfiles.localProxy.profile` selects existing per-device ciphertext, defaulting
to `laptop` for this machine. Other machines must select their own identity.
The shared `extra` profile is not eligible. A `wg-quick` client and sing-box
must not use the same peer identity simultaneously, including across machines.
The legacy whole-host aliases remain available but require the proxy backend
to be stopped first when they use its identity.

## Definition of done

- The generator validates supported profiles and rejects ambiguous or unsupported
  input without revealing credentials; output is private and atomically replaced.
- The flake evaluates and the activation package builds without decrypting secrets.
- The VM's three proxy URLs give tunnel egress while a direct request stays direct.
- Restart recovers; stopping removes listeners and runtime config, leaves host
  routes/rules/interfaces/resolver unchanged, and makes proxy requests fail.
- Linger is enabled through the normal dispatcher; startup before login is verified.
- Client routing and retirement are verified in their own tickets before closing
  this effort. Namespace functionality is not claimed by these proxy tests.

## Historical experiment

The earlier spec recorded an unprivileged sing-box 1.13.19 experiment on the
staging VM using the desktop-ubuntu profile and port 1080. It reported distinct
direct/proxy egress, no host networking changes, 43 MB resident memory, and
recovery after a 240-second hypervisor freeze. Those measurements were evidence
for the design, not a shipped implementation or a real suspend/network-change
test. Current implementation results belong in ticket 01.

## Tickets

See [map.md](map.md).
