# 04: Run whole-host VPN through the supervised TUN

Status: resolved
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

## Answer

The generated credential-free TUN passed the Fedora staging proof. On the
daily host, operator-approved activation replaced the `wg-quick` handover.
With the operator starting `vpn-up`, public HTTPS and UDP STUN used the TUN,
DNS selected `vpn-host0`, LAN and link-local routes selected `wlp1s0`, and
IPv6 default traffic was rejected. Stopping the user backend blocked
whole-host HTTPS; restarting it restored whole-host and `vpn` capture traffic.
After the operator ran `vpn-down`, the root unit was inactive, `vpn-host0` was
absent, public routing and DNS returned to `wlp1s0`, and the user backend and
capture still carried HTTPS. This checks normal use of this slice; longer
network-change and suspend recovery remain ticket 11, and legacy retirement
remains ticket 12.
