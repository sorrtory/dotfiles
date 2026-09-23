# Define failure and recovery for a pinned egress

Type: wayfinder:grilling
Status: resolved
Blocked by: None

## Question

If an app's pinned egress is missing from the inventory, cannot start, or
fails after launch, should its traffic fail closed, fall back to the runtime
default, or follow another explicit policy? Specify the operator-visible
error and what recovery may do without silently changing the route.

## Answer

An explicitly named egress that is absent from the inventory fails before
launch, with an error naming the missing egress and the app or command that
requested it. A configured egress that cannot start also fails the launch
explicitly. Neither case substitutes the active default.

If a selected egress becomes unreachable after launch, its traffic fails
closed. The running app remains pinned to the same name and may reconnect when
that egress recovers. It never silently changes to the default or another
provider. A network outage discovered after launch cannot always be reported
synchronously by the launcher; connection failure is the immediate signal.

Provide `vpn-egress check NAME` as an operator-invoked live reachability
diagnostic with a nonzero result and actionable output on failure. Reuse
sing-box's built-in URLTest for a named outbound or endpoint where the runtime
topology exposes it; do not build another HTTP probe just to duplicate it.
The pinned 1.14.1 Clash API implements `GET /proxies/{name}/delay` through
`urltest.URLTest` and returns an error for a failed probe. Its outbound lookup
also finds endpoints. See the [Clash API handler](https://github.com/SagerNet/sing-box/blob/v1.14.1/experimental/clashapi/proxies.go#L197-L250)
and [outbound lookup](https://github.com/SagerNet/sing-box/blob/v1.14.1/adapter/outbound/manager.go#L193-L201).

The built-in URLTest makes an HTTPS HEAD request over TCP; it does not prove
UDP, application DNS confinement, or future connectivity. Do not make every
app launch wait for this probe: a transient failure would block a launch that
could recover. `sing-box check` validates configuration only. The exact API
surface, access control, and any complementary DNS/UDP checks are decided
after the runtime topology.
