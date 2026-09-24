# 11: Record recovery through network change and real suspend

Status: resolved
Blocked by: 09 (installed-app pins)

**What to build:** Establish how the finished concurrent VPN behaves after
a real network/address change and suspend-to-RAM on the daily machine, both
with and without the whole-host TUN active. A VM pause is not a substitute.

- [x] Record recovery time, manual intervention, app and capture survival,
      selected egress, DNS confinement, and host route/resolver state for each
      case separately.
- [x] Verify the route through observable traffic and status, not just a
      running process; investigate reproduced failures before adding recovery
      machinery.
- [x] Mark behavior unavailable on staging when its VM cannot establish it;
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
Recovery time and scope survival across an observed physical network change
remained unmeasured until the later test below. This earlier evidence alone
was not enough to retire legacy VPN machinery.

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

The first cycle's temporary captured-DNS timeout deserved a timed repeat in
the later network-change check.

## Answer: observed physical network changes, 2026-09-24

The operator switched the daily host between `MIREGU5` (`192.168.10.77`) and
an alternate Wi-Fi network (`10.11.244.225`) twice while a two-second host
observer and long-lived processes in both installed-app pinned capture scopes
ran. The Vesktop-key probe used the laptop WireGuard peer; the AyuGram-key
probe used `orange-vless`. Each process repeatedly made real HTTPS requests
and DNS A/AAAA queries from inside its capture namespace. Before the switches,
both scopes were attached to their matching named capture and backend listener.
The same processes continued sampling across both switches; neither needed a
capture or backend restart. These were app-key traffic probes, not the GUI
application binaries. The prior suspend checks used the actual GUI apps. A
Fedora VM pause cannot establish physical Wi-Fi-change behavior, so staging
has no corresponding pass.

With the whole-host TUN **down**, the first observed alternate address was at
20:26:00 UTC. Host HTTPS stayed at 204 and public traffic used the alternate
Wi-Fi route and resolver. VLESS HTTPS had one transient TLS failure at
20:25:59, then returned 204 at 20:26:01. The WireGuard pinned probe timed out
on every HTTPS sample for the roughly 4.5 minutes spent on that network; it
did not recover there. On returning to `MIREGU5`, a Wi-Fi address was observed
at 20:30:28 and WireGuard HTTPS returned 204 by 20:30:27.8, the first probe
around that readback. There was no service restart. Host HTTPS had one failure
during the addressless transition, then returned 204 at the first original-
network sample.

With the TUN **up**, public IPv4 selected `vpn-host0`, its resolver was
selected, and HTTPS returned 204 before the switch. The first alternate
address was observed at 20:33:34. The selected WireGuard default and its
pinned scope timed out there while public traffic still selected `vpn-host0`;
the host did not fall back to Wi-Fi. VLESS pinned HTTPS recovered from one
transient TLS failure by 20:33:35. At 20:35:36, temporarily selecting VLESS
restored host HTTPS 204 through the same TUN on the alternate network, while
the WireGuard pin remained unavailable. This separates the working TUN and
VLESS path from the network-specific WireGuard failure. After switching back,
the original address was observed at 20:36:28; host HTTPS and both pinned
routes returned 204 by the first samples at 20:36:28–29. The WireGuard pin
recovered without a restart. The declarative WireGuard default was restored,
then `vpn-down` restored the physical Wi-Fi route and resolver, with host HTTPS
204. Both temporary scopes and the observer were stopped.

Across both switches, both capture probes always returned DNS A answers and
no AAAA answers. The earlier suspend-only captured-DNS timeout did not recur.
The two-second sampling bounds observed recovery but does not measure an exact
link-up instant. No service repair was needed; the manual default switch was
only the planned differential test. The results support a network-specific
WireGuard reachability problem, consistent with filtering, but do not prove
DPI as the mechanism. They do not justify adding recovery machinery to the
client. The legacy-retirement ticket can now use this evidence alongside
normal-use review.
