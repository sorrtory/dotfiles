# 10: Prove a real non-WireGuard egress

Status: needs-info
Blocked by: 09 (installed-app pins); a deployed server and credential are also required

**What to build:** Add a deployed VLESS or Hysteria2 egress using its native
sing-box entry and select it through the existing default and named-route
interfaces. No placeholder server or credential is created to satisfy this
ticket.

- [ ] Adding the route requires encrypted inventory and policy edits, not a
      new protocol adapter or application routing code.
- [ ] The real route carries proxy, one-off capture, pinned-app and whole-host
      TCP, UDP and DNS traffic as its capabilities permit.
- [ ] Switching to and from a WireGuard route works; provider loss fails
      closed on every selected entry point.
- [ ] A provider endpoint named by hostname bootstraps through fixed-address
      DNS bound to the physical route, never through host DNS.
- [ ] The operator supplies the server and credential through the established
      secret workflow before this ticket becomes ready for an agent.
