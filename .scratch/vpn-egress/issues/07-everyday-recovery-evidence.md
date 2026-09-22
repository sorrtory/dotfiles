# 07 — Evidence for network change and suspend-to-RAM

Status: ready-for-human

Blocked by: 03

## Goal

Close the last unproven recovery cases from the VPN command effort, on the
design that replaces it. Carried over from `vpn-command/05`, which proved
everything else: tunneled launches from all three entry points, a voice call,
private DNS, IPv6 no-escape, refusal of an untunneled Vesktop, backend restart,
capture failure, relaunch, a 45 s link drop and a 60 s VM pause.

It waits for 03 because both remaining cases exercise the whole-host tunnel
and the backend's interface binding, which that ticket replaces. Evidence
gathered before it would have to be gathered again.

## Work

For a change to a different network or address, and for a real guest
suspend-to-RAM — a VM pause is not a substitute — record:

- recovery time, and whether any manual step was needed
- whether capture and the application survived
- tunneled versus direct egress afterwards, and DNS confinement
- host routes and resolver unchanged
- the same with the whole-host tunnel up, which is new to this milestone

## Acceptance

- [ ] Both cases have separate written evidence, on the host where a real
      suspend and a real network change are possible.
- [ ] Coverage that staging cannot establish is recorded as unavailable, not
      marked passed.
- [ ] Any reproduced failure is investigated before recovery machinery is
      added; a running process is not treated as a healthy tunnel.
