# 08 — Retire the legacy VPN material

Status: ready-for-human

Blocked by: 07

## Goal

Close the retirement gate the VPN command effort deliberately left open. Its
documentation work is done; what remains is the operator review that allows
legacy sources to be removed. Carried over from `vpn-command/06`.

## Work

1. List the exact retirement targets: the external legacy `vpn.sh` outside
   this repository, the legacy whole-host WireGuard practice it encoded, and
   `reference/vpn-veth-port.sh` in this directory once nothing cites it.
2. Confirm normal everyday use across both this milestone's slices before
   removing anything. Removal follows use, not a passing test.
3. Remove only what the operator approves, one target at a time.
4. Fold anything durable that is still only in scratch into `CONTEXT.md`,
   `docs/DECISIONS.md` or `docs/MIGRATION.md` before this directory goes.

## Constraints

- Legacy data and session state are never deleted automatically.
- Operator review, host activation and retirement stay three distinct gates.

## Acceptance

- [ ] Every retirement target is named, reviewed and approved before removal.
- [ ] Canonical documentation carries everything durable; `.scratch/vpn-egress/`
      can be removed in the completion commit with Git history as its record.
