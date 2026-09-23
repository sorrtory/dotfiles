# Establish sing-box routing options for concurrent egresses

Type: wayfinder:research
Status: resolved
Blocked by: None

## Question

Using the pinned sing-box version and primary documentation, determine which
mechanisms can route simultaneous local proxy, whole-host TUN, and per-app
capture traffic to different outbound or endpoint tags. Check inbound tags,
multiple local listener ports, route rules, DNS detours, namespace instances,
and backend restarts. Report the mechanisms' limits and whether a single
backend or separate instances can preserve fail-closed routing and secret
handling. This is fact-finding, not the topology decision.

## Answer

The installed sing-box is 1.14.1. Its route rules can match an inbound tag and
select an outbound tag, so distinct loopback listeners can carry concurrent
egress choices in one backend. The route's `final` is the unpinned default.
See the official [inbound](https://sing-box.sagernet.org/configuration/inbound/),
[listen](https://sing-box.sagernet.org/configuration/shared/listen/),
[route rule](https://sing-box.sagernet.org/configuration/route/rule/), and
[route action](https://sing-box.sagernet.org/configuration/route/rule_action/)
documentation.

DNS needs its own rules: a DNS rule can match the inbound, and each DNS server's
`detour` must name the intended egress. A UDP DNS server with no detour can
dial directly, regardless of the traffic route's `final`. See the official
[DNS rule](https://sing-box.sagernet.org/configuration/dns/rule/),
[DNS action](https://sing-box.sagernet.org/configuration/dns/rule_action/), and
[UDP DNS server](https://sing-box.sagernet.org/configuration/dns/server/udp/)
documentation. Runtime proof is still needed for this repository's capture
resolver and endpoint-hostname cases.

The whole-host TUN can remain a separate credential-free instance that sends
traffic to a selected backend listener. Its route and interface loop-prevention
settings need verification with that layout; see the official
[TUN documentation](https://sing-box.sagernet.org/configuration/inbound/tun/).

On SIGHUP, the pinned release checks a new configuration, then closes and
recreates the instance, interrupting existing flows; a failed preflight leaves
the old instance running. See the
[1.14.1 source](https://github.com/SagerNet/sing-box/blob/v1.14.1/cmd/sing-box/cmd_run.go#L178-L213).
A single backend configured with every candidate parses all those credentials
at startup; this is an inference from the
[configuration loading path](https://github.com/SagerNet/sing-box/blob/v1.14.1/cmd/sing-box/cmd_run.go#L45-L138).
Separate processes can reduce credentials per process but do not by themselves
reduce a user's access to the decrypted inventory.
