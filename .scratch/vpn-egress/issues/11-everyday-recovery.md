# 11: Record recovery through network change and real suspend

Status: claimed
Blocked by: 09 (installed-app pins)

**What to build:** Establish how the finished concurrent VPN behaves after
a real network/address change and suspend-to-RAM on the daily machine, both
with and without the whole-host TUN active. A VM pause is not a substitute.

- [ ] Record recovery time, manual intervention, app and capture survival,
      selected egress, DNS confinement, and host route/resolver state for each
      case separately.
- [ ] Verify the route through observable traffic and status, not just a
      running process; investigate reproduced failures before adding recovery
      machinery.
- [ ] Mark behavior unavailable on staging when its VM cannot establish it;
      do not report that gap as a pass.

## Progress, 2026-09-24

The daily host changed from a `192.168.10.x` Wi-Fi network to a
`10.169.126.x` network before the timed observer started, so this is
post-change evidence rather than a recovery-time measurement. On the new
network, both named backend probes passed and Vesktop's WireGuard and
AyuGram's VLESS app-key captures each returned HTTPS 204 and DNS A answers.
Both real apps were then launched in their pinned capture namespaces.

With the whole-host TUN enabled on that network, public traffic used
`vpn-host0`, the local gateway stayed on `wlp1s0`, and the TUN resolver was
selected. Whole-host HTTPS and both pinned app paths returned 204; both app
scopes remained attached with matching process namespaces. After `vpn-down`,
the TUN was absent and the direct Wi-Fi route, resolver and HTTPS 204 returned.
A temporary read-only observer sampled 127 times across the TUN cycle and saw
one transient HTTPS failure during a route transition. The observer and its
temporary files were removed.

The operator could not switch back to the original network during this run.
Recovery time, scope survival across an observed physical network change,
and scope survival across an observed physical network change remain
unmeasured. No legacy VPN machinery is eligible for removal on this evidence
alone.

## Real suspend/resume on the alternate network

The operator explicitly approved and woke the daily host for two real
suspend/resume cycles with both graphical apps active in their pinned scopes.
A read-only observer used `CLOCK_BOOTTIME` and `CLOCK_MONOTONIC` to detect
sleep intervals and sampled actual public HTTPS, routes, and, in the TUN-up
case, DNS from each capture namespace. It was stopped and removed afterward.

With the TUN down, the observed sleep interval was about 4.1 seconds. The
first post-resume HTTPS sample failed DNS resolution at 14:55:01 UTC; the
next sample returned 204 at 14:55:02. Fresh DNS queries in both app captures
initially timed out, then later returned A answers without a manual service
restart. The host resolver and direct UDP DNS also worked. Exact captured-DNS
recovery time was not measured in this first cycle. Vesktop and AyuGram kept
the same scope and network namespace identities; both named routes and app
HTTPS returned normally after recovery. The default selector stayed on the
declarative WireGuard route, public routing remained on Wi-Fi, and the Wi-Fi
resolver was selected.

With the TUN up, the observed sleep interval was about 10.8 seconds. The
first post-resume sample at 14:59:26 UTC already returned HTTPS 204 and DNS A
answers from both named capture namespaces; this bounds observed recovery to
the first sample, not a precise zero-second recovery time. Both real app
scopes kept their pre-suspend identities and returned HTTPS 204. Public traffic
still used `vpn-host0`, the local gateway stayed on Wi-Fi, the TUN resolver
was selected, and the declarative WireGuard default was unchanged. After
`vpn-down`, the TUN unit and interface were absent and the direct Wi-Fi route,
resolver and HTTPS 204 returned. No intervention beyond physically waking
the host and the planned `vpn-down` was needed.

The first cycle's temporary captured-DNS timeout deserves a timed repeat if
it occurs during a later network-change check. The real network change with
and without the TUN remains the closing gate for this ticket.
