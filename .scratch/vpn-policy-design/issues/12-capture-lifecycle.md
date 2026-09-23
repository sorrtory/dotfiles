# Define capture and pinned-app lifecycle

Type: wayfinder:grilling
Status: resolved
Blocked by: 11

## Question

With a shared backend and one on-demand namespace per selected route, decide
when a capture starts and stops, how simultaneous launches hold it alive, and
what happens to running VPNized apps when their pinned egress is removed or
reconfigured by a Home Manager switch. A shared backend restart interrupts
all routes; specify whether apps reconnect in their existing capture,
fail until relaunched, or are deliberately stopped. Avoid any fallback to a
new default or the host network, including after a namespace service exits.

State the ownership of app launch scopes versus capture service units, and
which observable status/readback proves that a route remains attached to its
intended namespace during a default switch and after a failed backend restart.

## Answer

Each `vpn` launch owns a distinct user systemd app scope and records its
resolved route (`default` or a named egress) and, for an installed app, the
policy key that selected it. The scope requires and binds to the matching
route-specific capture service. Launch and capture creation are serialized
against policy replacement: the route is resolved once, and a scope cannot
enter a namespace whose recorded route differs. Multiple scopes on one route
share its capture; the last scope's exit lets that service stop. A capture
failure stops its bound scopes and their payloads, including applications
that move their main process into another scope. A missing or failed capture
never releases a payload onto the host network.

The default capture connects only to the backend selector listener. Each
named capture connects only to the listener bound to its stable egress tag.
The capture's user-only runtime record holds the route tag, backend listener
binding, namespace PID and inode, and the route definition revision. A
readback command must compare that record with the active backend binding and
the app scope's recorded route. It must distinguish an attached route, a
backend outage (attached but network-dead), and a mismatch that requires
stopping the affected scopes. A default selector switch changes only the
selected outbound; it does not change the default capture's binding or any
named capture's binding. Named listener addresses must not be reassigned to
another tag while a capture can still use them.

An ordinary backend restart with the same route definitions leaves capture
services and app scopes running. Connections can fail during the outage and
the app may reconnect through the same namespace when the listener returns.
The capture does not depend on backend process liveness for its own lifetime.
If restart fails, traffic remains blocked and readback reports the outage;
the app never falls back to the default or host network.

Before a Home Manager switch replaces backend/policy runtime state, validate
the new inventory and policy and compare them to the active bindings. Stop an
installed app's scope if its pin changes or disappears. Stop every scope on a
named route, including one-off `vpn --egress NAME` scopes, if that route is
removed or its definition or capture policy changes (including IPv6
capability). Let a capture stop when its last scope exits, and require it to
stop before replacing its binding. A pin change alone does not stop an old
capture still used by unaffected scopes. Report each stopped app, old route,
and reason explicitly; the operator relaunches it under the new policy.
Unaffected pinned scopes remain running and may reconnect after a shared
backend restart. A Home Manager switch still resets the runtime default, so
unpinned traffic follows the new declarative default as previously decided.

If preflight or reconciliation fails, do not install a backend binding that
could repurpose a live capture's listener. Fail the switch with an explicit
error or leave the affected traffic network-dead until it can be stopped;
never silently reroute it. Implementation must prove scope-to-capture
lifetime, readback after default switch and failed backend restart, and
reconciliation of a changed pin and a removed route on staging before host
activation.
