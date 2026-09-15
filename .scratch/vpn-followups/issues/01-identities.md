# 01 — Settle profiles, egress and system-wide use

Status: resolved

## Goal

Turn the original several-identities proposal into a coherent implementation
sequence without conflating credentials, selectable routes, application policy
and host tunnel lifecycle.

## Answer

The design is captured in ../spec.md and split across tickets 03–08.

- Use a declarative list of allowed, stably named egresses. Protocol kind is an
  implementation detail of each tagged entry.
- Start with native WireGuard and exact-interface system egresses. Add VLESS or
  another adapter only when a real server transport exists.
- Configure one default and manual alternatives. Automatic fallback is not
  implied and is separately gated.
- Use an authenticated loopback Clash controller behind the supported
  `vpn-egress` command. Preserve runtime selection across backend restart and
  reset it at logout/reboot.
- Interrupt existing TCP and UDP flows during a switch so applications reconnect
  through the selected route; do not promise an uninterrupted voice call.
- Manage only `wg-quick` in `vpn-up/down`. Other declared interfaces, including
  v2rayN TUN, have externally owned lifecycle.
- Use a distinct system-wide WireGuard identity. Never expose unbound direct.
- Applications follow global selection unless explicitly pinned; the dedicated
  milestone includes `vpn --egress` for one-off use.
- Keep multi-machine configuration extensible but do not design desktop-specific
  identity policy now. Staging live-tests with a disposable uncommitted peer.

The prior proposal to change egress by restarting sing-box was replaced by the
selector controller. A selector-only switch with the same WireGuard identity
was rejected: sing-box 1.14 keeps the endpoint instantiated and its keepalive
can still compete with `wg-quick`; current DNS also bypasses such a selector.
