# 04 — Add the authenticated runtime selector

Status: ready-for-agent
Blocked by: 03

## Goal

Expose a small `vpn-egress` interface that changes the compiled selector live
without restarting sing-box and without exposing raw controller semantics to
ordinary callers.

## Interface

```text
vpn-egress list
vpn-egress status
vpn-egress use EGRESS
vpn-egress default
```

## Work

1. Enable the pinned sing-box 1.14 Clash controller on loopback with a generated
   bearer secret held in a mode-0600 runtime path. It is TCP-only; never bind it
   to a non-loopback address.
2. Package `vpn-egress` as the supported interface. Validate IDs, serialize
   mutations, update private runtime intent atomically, call only the owned
   selector and verify requested versus actual state. Raw controller changes are
   unsupported and must not be documented as a stable interface.
3. Configure selector changes to interrupt existing inbound connections so TCP
   and UDP reconnect through the new egress.
4. Preserve intent across a sing-box service restart without using persistent
   state: reconcile before traffic can leave on the wrong egress. Runtime intent
   disappears on logout/reboot and the declared default returns.
5. If a selected system interface is absent, select/block traffic rather than
   fall back to the host uplink. `status` distinguishes requested, actual,
   available and structurally unavailable states without exposing credentials.

## Acceptance

- List/status/use/default work for every declared fixture entry and reject all
  other IDs without altering the working selection.
- Concurrent mutations cannot leave state and selector disagreeing silently.
- Backend restart restores a valid runtime selection; a fresh runtime restores
  default; missing/disappearing interfaces fail closed.
- TCP, UDP and DNS switch together. Existing flows are interrupted and recover
  through the new route; an uninterrupted call is not claimed.
- Controller authentication, permissions and non-loopback refusal are tested.
