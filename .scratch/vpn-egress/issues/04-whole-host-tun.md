# 04: Run whole-host VPN through the supervised TUN

Status: ready-for-agent
Blocked by: 03 (shared VPN runtime)

**What to build:** Make `vpn-up` and `vpn-down` operate a credential-free,
supervised sing-box TUN through the current one-identity user backend. The
backend keeps its credential and binds upstream traffic to the physical
interface, ending the `wg-quick` peer handover before concurrent egresses
arrive.

- [ ] Public TCP, UDP and DNS use the TUN and current backend; LAN and
      link-local routes stay reachable, with no routing loop or direct
      fallback when the backend fails.
- [ ] Default traffic remains IPv4-only, including when a native IPv6 route
      exists. Repeated up/down actions restore routes and resolver state.
- [ ] The root unit holds no VPN credential. Its Fedora SELinux launch follows
      the supervised staging proof; only explicit `vpn-up` may prompt for
      sudo, never Home Manager activation.
- [ ] The generated configuration passes the full staging routing proof,
      and normal use is checked before retiring active `wg-quick` handover.
- [ ] Daily-host activation requires separate operator approval; a reviewed
      rollback generation remains available.
