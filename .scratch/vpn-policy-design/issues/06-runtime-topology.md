# Choose the runtime and capture topology

Type: wayfinder:grilling
Status: resolved
Blocked by: 01, 02, 03, 04, 05

## Question

Given the settled policy and sing-box capabilities, choose where the egress
selection seam lives: one backend with distinct entry points, separate
backends or capture instances per egress, or another concrete arrangement.
Define the smallest caller interface for `vpn`, installed app launchers, the
local proxy, and the whole-host TUN, and how concurrent launches share or
isolate runtime state. Account for default switches that interrupt default
flows while leaving pinned routes and their running applications on their
selected egress. Decide whether a local sing-box API is part of the interface
for manual selection and named health checks, and how its control access is
restricted.

## Answer

Use one unprivileged, credential-bearing sing-box backend that loads all named
egresses at startup. Its manually controlled selector serves only the active
default. The local proxy and the credential-free whole-host TUN enter through
that selector. Named pins enter through distinct listeners routed directly to
their named outbound or endpoint tags; they do not pass through the selector or
an automatic `urltest` group.

`vpn` resolves an explicit `--egress NAME` or an installed application's pin
from the decrypted policy at launch. Otherwise it uses the active default.
Start one capture namespace on demand for each selected route and share it
among launches that select that route. The default capture connects to the
selector listener; a named capture connects to its own named listener. Route
identity must be part of the namespace/service identity so concurrent pins
cannot accidentally share the default capture.

`vpn-egress use NAME` changes only the selector choice for this runtime. It
may interrupt default traffic, including connections in the default capture
and whole-host TUN, while named captures and their backend routes remain
selected. Reboot and Home Manager switch restore the declarative default.
Restarting or reconfiguring the shared backend can still interrupt every
route; preserving connections across those operations is not promised.

A local sing-box control API is needed for manual selector changes and the
named live diagnostic. Its exact API, socket/listener, authentication, and
wrapper behavior are assigned to [Define the live egress check](08-live-egress-check.md).
The selected topology remains conditional on [Prove DNS and capture routing](09-prove-routing-topology.md): establish that concurrent captures, DNS,
IPv6 handling, and the whole-host path select the intended egress and fail
closed before treating the spec as final.
