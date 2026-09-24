# 09: Keep installed applications on their declared egresses

Status: resolved
Blocked by: 07 (runtime default control), 08 (one-off named capture)

**What to build:** Vesktop and AyuGram launch through named policy pins when
configured, or through the active default otherwise. They may use different
egresses at once. A Home Manager switch stops only scopes whose app pin or
named route definition changes, with an explicit reason; unaffected apps
keep their capture and can reconnect after a backend restart.

- [x] App launchers supply stable app keys. Explicit `--egress` takes
      precedence over the app pin, which takes precedence over the active
      default; an unknown pin fails before launch.
- [x] Two pinned apps continue on distinct routes while the default changes;
      DNS, UDP and IPv6 follow each app's chosen route without fallback.
- [x] A changed or removed app pin stops that app scope; a removed or changed
      named route stops every scope using it. An old capture remains until
      its last unaffected scope exits, and no live listener is repurposed.
- [x] Runtime readback compares scope route, namespace identity and backend
      binding, distinguishing an outage from a mismatch. Failed
      reconciliation cannot silently change an app's route.
- [x] Staging exercises pin changes, route removal, backend restarts and
      simultaneous apps; real host app activation needs separate approval.

Staging on Fedora 44 checked the stable app-key launch path with Vesktop pinned
to its own WireGuard peer and AyuGram to VLESS. Both named captures stayed
attached in distinct network namespaces while the active default changed.
Both routes carried HTTPS 204 and UDP DNS A answers, returned no AAAA answers,
and blocked IPv6 HTTPS. Stopping the backend reported `backend-outage` for
both captures; restarting it restored `attached` and HTTPS 204. A temporary
pin switch stopped only the affected app scope. Removing VLESS and its app pin
in a temporary encrypted VM inventory stopped its app and one-off scopes while
the WireGuard app scope remained attached. The original VM ciphertext and
generation were restored.

## Answer

The reviewed host generation
`/nix/store/c125smml902z3wp3plagz9kh90vgiqwv-home-manager-generation`
activated with the ticket 08 generation retained for rollback. It stopped one
pre-pin scope whose app identity was unknown, then AyuGram was relaunched on
VLESS and Vesktop on the host's `laptop` WireGuard peer. Both actual app scopes
remained active at once. `vpn-egress inspect` reported distinct capture
namespaces, each app scope's process namespace matched its capture, and both
backend bindings matched. Changing the active default to VLESS left the pins
attached; each pinned HTTPS request returned 204. Both captures returned UDP
DNS A answers, no AAAA answers, and blocked IPv6 HTTPS. Backend loss reported
`backend-outage` for both and blocked AyuGram traffic; backend restart restored
`attached` and HTTPS 204 on both routes. The default was restored to WireGuard.

Review against `e2328fe` found a per-scope namespace readback gap, fixed in
`35415a1` and re-reviewed with no blocking findings. The remaining small
duplication in the two app launchers is accepted as their separate ownership
boundary.
