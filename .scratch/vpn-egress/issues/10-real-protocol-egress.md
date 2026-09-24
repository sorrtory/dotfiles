# 10: Prove a real non-WireGuard egress

Status: resolved
Blocked by: 09 (installed-app pins)

The operator added a native `orange-vless` outbound and its encrypted policy
entry on 2026-09-24, and confirmed that both machines may use it concurrently.
The Fedora staging VM reached HTTPS and received DNS A answers over UDP
through its named listener while its own WireGuard default remained active.
Full one-off capture, pinned-app, selector and whole-host checks follow the
preceding tickets; this ticket remains blocked by 09.

**What to build:** Add a deployed VLESS or Hysteria2 egress using its native
sing-box entry and select it through the existing default and named-route
interfaces. No placeholder server or credential is created to satisfy this
ticket.

- [x] Adding the route requires encrypted inventory and policy edits, not a
      new protocol adapter or application routing code.
- [x] The real route carries proxy, one-off capture, pinned-app and whole-host
      TCP, UDP and DNS traffic as its capabilities permit.
- [x] Switching to and from a WireGuard route works; provider loss fails
      closed on every selected entry point.
- [x] The deployed endpoint is an IP literal, so hostname bootstrap is not
      needed. The compiler rejects hostname endpoints without physical-route
      bootstrap rather than resolving them through host DNS.
- [x] The operator supplies the server and credential through the established
      secret workflow before this ticket becomes ready for an agent.

## Answer

The operator's native VLESS outbound is stored only in the SOPS inventory. No
protocol adapter or app route branch was added. Prior staging and host checks
covered default proxy, named one-off capture, selector switching and VLESS
HTTPS/DNS. Ticket 09 then launched real AyuGram pinned to VLESS on the daily
host. Its capture carried HTTPS 204, UDP DNS A/no AAAA, and a matching UDP
STUN response while Vesktop used a separate WireGuard peer.

For provider-loss staging, a temporary encrypted VM inventory pointed only
the VLESS server at the reserved unreachable address `192.0.2.1`. VLESS local
proxy, one-off capture, pinned AyuGram path, default capture and whole-host
TUN all blocked; the independent WireGuard pinned route still returned HTTPS
204. The VM's original ciphertext, generation, WireGuard default and direct
route were restored and compared to the source files. This simulates endpoint
loss; it is not a measurement of a real provider outage.

On the daily host, selecting VLESS under `vpn-up` carried direct HTTPS 204 and
a matching UDP STUN response through `vpn-host0`, while LAN stayed on Wi-Fi.
`vpn-down` removed the TUN; direct Wi-Fi routing, resolver and HTTPS 204
returned. `vpn-egress default` restored the declarative laptop WireGuard
selection. The endpoint is an IP literal, and the compiler refuses hostname
endpoints until a fixed-address resolver bound to the physical route exists.
