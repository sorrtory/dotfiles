# 08: Launch one-off programs through a named capture

Status: claimed
Blocked by: 06 (concurrent backend routes)

**What to build:** `vpn --egress NAME -- PROGRAM` runs one command through a
capture namespace bound directly to that named egress. Unpinned `vpn`
continues through the default selector, and multiple commands can share one
named capture.

- [x] An unknown name or invalid route fails before payload launch; an
      unreachable configured route remains selected and network-dead until
      recovery, with no host or default fallback.
- [x] TCP, UDP and DNS use the named listener; IPv6 follows that egress's
      declared capability. A default selector switch leaves the named route
      unchanged.
- [x] Each command has a scope bound to the chosen capture; simultaneous
      scopes share it, last exit stops it, and capture failure stops payloads.
- [x] Route, listener and namespace readback identifies an attached route or
      backend outage. Until selective policy reconciliation exists, a Home
      Manager switch stops live named scopes before any listener rebinding.
- [x] Staging proves a named launch, a default launch and a backend outage
      concurrently before separately approved host activation.

## Staging evidence

The disposable Fedora VM built and activated the named-capture generation.
`vpn --egress orange-vless -- curl` and unpinned `vpn -- curl` both returned
HTTPS 204. Named DNS returned an A answer over UDP and no AAAA answer under
the route's IPv4-only policy. An unknown name returned before its `touch`
payload ran. Two simultaneous named scopes shared one capture; the first exit
left it active and the last exit stopped it. Stopping the capture ended its
bound `sleep` payload in one second with exit 143. With named and default
captures already active, stopping the backend made both HTTPS requests time
out; restarting it restored both. A transient VLESS timeout affected its
direct listener and named capture together, while named WireGuard and the
default remained usable; a backend restart restored VLESS. Readback matched
the named backend listener and capture SOCKS port (53749), an active listener,
a distinct namespace inode and the scope's capture dependency. A Home Manager
activation while a named scope was live stopped that scope before service
reload; the scope exited 143 and the capture stopped. Daily-host activation
remains separately gated.
