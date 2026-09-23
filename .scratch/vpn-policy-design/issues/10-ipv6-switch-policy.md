# Define IPv6 behavior across default switches

Type: wayfinder:grilling
Status: resolved
Blocked by: 09

## Question

The default capture namespace remains alive when `vpn-egress use NAME` changes
the selector. An egress that supports IPv6 may replace one that does not, or
vice versa, while DNS strategy, TUN addresses, and route rules in that capture
remain fixed. Which observable policy should the default capture expose?

Compare keeping a dual-stack capture and rejecting IPv6 in the backend for
egresses without IPv6, restarting only the default capture on a capability
change, and consistently offering IPv4-only to the default capture. Require
that no IPv6 packet or DNS AAAA answer escapes through the host. Specify the
behavior for pinned captures, whose named egress is fixed at launch, and the
acceptance proof for both capability directions.

## Comments

On 2026-09-23, the staging VM became reachable again through its documented
SSH key. It has sing-box 1.14.1, a running user backend, and IPv4 default route
on `enp1s0`; it has no IPv6 default route. No staging configuration was changed.

The current capture generator fixes the TUN address family and DNS strategy
when its namespace starts. Keeping one default capture alive across selector
changes therefore requires a stable policy. Recommended for this rewrite:
make all default entry points IPv4-only and explicitly reject IPv6, while a
fixed named capture uses its egress's declared IPv6 capability. This is a
functional limit on IPv6-capable default egresses, but does not require a
capture restart or give apps unusable AAAA answers after switching to an
IPv4-only egress. The operator chose this policy.

## Answer

Keep every default entry point IPv4-only for this rewrite: the local proxy,
the default capture namespace, and the whole-host TUN. A default switch
changes the selected egress without changing DNS strategy, TUN addresses, or
the address family visible to unpinned applications. Default DNS returns only
IPv4 answers; an IPv6 literal or packet is rejected inside the confined path.
The whole-host TUN must also intercept or reject host IPv6 so it cannot use a
native host IPv6 route while the VPN is up. This is an intentional limit even
when the selected default egress supports IPv6.

A named capture is fixed to its named egress and is generated once from that
egress's IPv6 capability in encrypted `policy.jsonc`. A named egress marked
IPv4-only gets no IPv6 capture route and no AAAA answers. A named egress marked
IPv6-capable may carry IPv6 and AAAA through that same named route. An
explicit `vpn --egress NAME` follows the same named policy. A default switch
never changes a named capture's IPv6 behavior.

The staging proof must test default IPv6 rejection with a synthetic IPv6 route,
because the VM currently has no native IPv6 default route. It must also test
an IPv6-capable named capture in a disposable fixture. Until those checks are
observed, the policy is chosen but the fail-closed claim is unverified.
