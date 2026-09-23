# 11: Record recovery through network change and real suspend

Status: ready-for-human
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
