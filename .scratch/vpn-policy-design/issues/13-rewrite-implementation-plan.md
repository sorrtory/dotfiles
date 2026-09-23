# Rewrite the implementation spec and tickets

Type: wayfinder:task
Status: resolved
Blocked by: 07, 12

## Work

Make `.scratch/vpn-egress/spec.md` internally consistent with the concurrent
policy and [migration order](07-migration-order.md). Replace implementation
tickets 01–03 rather than leaving their obsolete single-egress work lists
under `needs-redesign`. Add separate, independently verifiable tickets for
the mechanical module split and pinned-capture lifecycle. Update their
dependencies and `.scratch/vpn-egress/map.md` so the first implementable
ticket is clear. Preserve the independent AppArmor, relative-executable,
real-provider, normal-use and retirement gates.

Capture the Fedora root systemd launch proof and its remaining full-config
verification gate. Keep staging's unrecovered secrets as an explicit limit.
Do not implement or activate the VPN rewrite in this ticket.

## Acceptance

- Every settled design decision has an implementation owner and check.
- No ticket directs an agent to build one-credential or persistent-selector
  behavior that the design replaced.
- Each cutover can be reviewed before host activation, and removal follows
  normal-use evidence.

## Answer

The [egress spec](../../vpn-egress/spec.md) is now `planned`, and its
[implementation map](../../vpn-egress/map.md) identifies ticket 09 as the
first main slice. Tickets 01–03 were replaced with concurrent backend,
runtime control and TUN cutover work. New tickets 09–11 cover the mechanical
module split, pinned-capture lifecycle and TUN preparation. The dependencies
put the TUN before the all-egress backend. Independent AppArmor and relative
path defects remain independent; real-provider, normal-use and retirement
gates remain later work.

The staging SELinux remedy is recorded as a proven root service launch with
a host-labeled `/usr/bin/env` first in the unit. A later
[staging proof](11-whole-host-route-proof.md) ran the full synthetic TUN
configuration in that supervised unit. The eventual generated configuration
and real credentials remain implementation checks. Staging secret recovery
is still required before real-credential verification there. No live module,
secret, service or Home Manager generation was changed by this design map.

## Comments

The later `to-tickets` pass replaced that temporary numbering. The current
[implementation map](../../vpn-egress/map.md) starts with independent AyuGram
and Vesktop refactor tickets 01 and 02, then shared runtime ticket 03. Its
numbered blockers supersede the ticket-09 reference in the answer above.
