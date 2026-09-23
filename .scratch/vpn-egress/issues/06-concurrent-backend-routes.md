# 06: Serve concurrent default and named egress routes

Status: ready-for-agent
Blocked by: 05 (native default inventory)

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
