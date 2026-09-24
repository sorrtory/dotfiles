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
and both suspend/resume cases remain unmeasured. No legacy VPN machinery is
eligible for removal on this evidence alone.
