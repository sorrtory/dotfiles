# 08: Launch one-off programs through a named capture

Status: ready-for-agent
Blocked by: 06 (concurrent backend routes)

**What to build:** `vpn --egress NAME -- PROGRAM` runs one command through a
capture namespace bound directly to that named egress. Unpinned `vpn`
continues through the default selector, and multiple commands can share one
named capture.

- [ ] An unknown name or invalid route fails before payload launch; an
      unreachable configured route remains selected and network-dead until
      recovery, with no host or default fallback.
- [ ] TCP, UDP and DNS use the named listener; IPv6 follows that egress's
      declared capability. A default selector switch leaves the named route
      unchanged.
- [ ] Each command has a scope bound to the chosen capture; simultaneous
      scopes share it, last exit stops it, and capture failure stops payloads.
- [ ] Route, listener and namespace readback identifies an attached route or
      backend outage. Until selective policy reconciliation exists, a Home
      Manager switch stops live named scopes before any listener rebinding.
- [ ] Staging proves a named launch, a default launch and a backend outage
      concurrently before separately approved host activation.
