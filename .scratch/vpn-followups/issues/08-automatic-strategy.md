# 08 — Decide whether egress selection should become automatic

Status: needs-info
Blocked by: 07

## Goal

Decide from real use whether manual alternatives are insufficient, then choose
and name one automatic policy accurately.

Normal-use evidence from at least two adapters is required before triage.

## Decision gate

- `urltest` actively probes and chooses measured latency; it tracks TCP and UDP
  separately and does not retry a failed request through the next candidate.
- Ordered failover requires repository-owned health, selection, retry/reconcile
  semantics and is not provided by sing-box 1.14's selector/urltest groups.
- Define acceptable probe traffic, detection/recovery time, hysteresis, failure
  visibility and whether an active call may be interrupted automatically.

## Acceptance

Do not implement until at least two real adapters have normal-use evidence and
the operator selects latency choice, ordered failover or continued manual use.
Any implementation keeps explicit status/manual override and never falls back
to an unbound direct uplink.
