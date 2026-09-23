# Define default and pinned egress behavior

Type: wayfinder:grilling
Status: resolved
Blocked by: None

## Question

When `vpn-egress use B` changes the runtime default while Vesktop is pinned
to A, which entry points move to B and which remain on A? Specify local proxy,
ordinary `vpn` launches, `vpn --egress A`, pinned app launchers, and the
whole-host tunnel, including what happens to already-running programs.

## Answer

The encrypted policy's per-host default is the declarative default. Running
`vpn-egress use B` temporarily changes the active default to B for this user
session. It does not edit either JSONC file and does not survive a reboot or a
Home Manager switch; either event restores the declarative default. The
`vpn-egress default` command clears a temporary choice immediately.

The active default governs the local proxy, unpinned `vpn` launches, and the
whole-host tunnel. A launch with `vpn --egress A` and an installed app pinned
to A remain routed to A when the active default changes. Connections using
the old default are interrupted and recover through B. Pinned programs keep
their selected route and should continue through A; the runtime-topology
decision must account for the fact that restarting one shared sing-box process
would also interrupt their live connections.

This reverses the current `.scratch/vpn-egress/spec.md` statement that the
saved choice survives reboots and its ticket to persist that choice. The
implementation spec must be rewritten before those tickets are started.
