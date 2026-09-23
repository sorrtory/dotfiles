# 06: Serve concurrent default and named egress routes

Status: claimed
Blocked by: 05 (native default inventory)

The operator chose to keep only the current host and staging WireGuard peers.
Those peers are already active on their respective machines, so loading both
in one backend would make one peer roam between clients. Concurrent real-route
validation needs additional independent peers or another provisioned egress.
The existing synthetic routing proof remains available for implementation
checks, but cannot establish real concurrent operation on these identities.

The compiler now has an explicit `--concurrent` candidate mode. It is not
selected by the installed service. A synthetic two-route fixture checks stable
loopback bindings, direct named route and DNS rules, default IPv4 policy, and
capture/TUN resolver generation. On the Fedora VM, the generated candidate
sent default and named HTTP to the intended synthetic SOCKS egresses; disabling
one named egress left the other working. The VM's installed real-peer service
was restored and its proxy passed HTTPS. The real encrypted inventory also
passed `sing-box check` in candidate mode without starting another peer.
Generated named UDP also followed its assigned synthetic route on the VM.
The candidate currently requires a shared primary DNS address across routes,
so a selector switch cannot retain the previous route's private resolver.
The operator added a shared VLESS outbound and confirmed both machines may use
it concurrently. The encrypted policy now assigns each WireGuard peer to one
hostname, independent of the temporary or declarative default. On the Fedora
VM, the installed concurrent backend loaded its own WireGuard peer plus VLESS
and served HTTPS and DNS over UDP through both generated listeners. IPv6 was
rejected on both routes as declared. Default capture, whole-host TUN, backend
loss and restoration, and `vpn-down` cleanup passed with that backend. The
daily-host activation remains separately gated. Default switching belongs to
ticket 07; named capture belongs to ticket 08.

Review added a private per-session listener binding record, so a removed
route's port cannot be reused by another tag while an old capture may still
exist. The compiler also rejects hostname servers until physical-route-bound
bootstrap DNS is implemented. The revised VM generation passed its synthetic
collision and hostname fixtures, created the binding record at mode `0600`,
kept IPv4-only DNS, and continued to serve the real VLESS route.

**What to build:** Load the encrypted egress inventory into one unprivileged
backend. Keep the existing local proxy and default capture usable through a
manual default selector while distinct named listeners route directly to
their matching egresses.

- [ ] Multiple configured egresses load in one backend, with stable listener
      bindings that cannot silently be reassigned to another name.
- [ ] Default proxy and capture traffic use the selector; named-listener TCP,
      UDP and DNS use only their named route, without default fallback.
- [ ] Default entry points reject IPv6 and return no AAAA answers; named
      listeners follow their declared IPv6 capability.
- [ ] A failed named egress does not affect another named route or substitute
      the default. Backend restart interrupts connections but compatible
      capture namespaces can reconnect to the same binding.
- [ ] Synthetic staging traffic identifies each route through its actual
      listener and DNS path before a separately approved host cutover.
