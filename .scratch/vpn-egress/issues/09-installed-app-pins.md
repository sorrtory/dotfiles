# 09: Keep installed applications on their declared egresses

Status: ready-for-agent
Blocked by: 07 (runtime default control), 08 (one-off named capture)

**What to build:** Vesktop and AyuGram launch through named policy pins when
configured, or through the active default otherwise. They may use different
egresses at once. A Home Manager switch stops only scopes whose app pin or
named route definition changes, with an explicit reason; unaffected apps
keep their capture and can reconnect after a backend restart.

- [ ] App launchers supply stable app keys. Explicit `--egress` takes
      precedence over the app pin, which takes precedence over the active
      default; an unknown pin fails before launch.
- [ ] Two pinned apps continue on distinct routes while the default changes;
      DNS, UDP and IPv6 follow each app's chosen route without fallback.
- [ ] A changed or removed app pin stops that app scope; a removed or changed
      named route stops every scope using it. An old capture remains until
      its last unaffected scope exits, and no live listener is repurposed.
- [ ] Runtime readback compares scope route, namespace identity and backend
      binding, distinguishing an outage from a mismatch. Failed
      reconciliation cannot silently change an app's route.
- [ ] Staging exercises pin changes, route removal, backend restarts and
      simultaneous apps; real host app activation needs separate approval.
