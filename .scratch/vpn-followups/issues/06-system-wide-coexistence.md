# 06 — Manage system-wide WireGuard without breaking local consumers

Status: ready-for-agent
Blocked by: 04

## Goal

Make `vpn-up/down` manage declared `wg-quick` activations while the local proxy,
`vpn` and VPNized apps continue using the same running sing-box backend through
its interface-bound egress.

## Interface and ownership

- `vpn-up [EGRESS]` accepts only a system-interface entry with `wg-quick`
  activation. No argument works when exactly one such entry is declared; with
  several, the ID is required rather than adding another default concept.
- `vpn-down` stops the one managed active tunnel and restores default egress.
- At most one managed system-wide tunnel is active. v2rayN and other TUN clients
  remain externally started/stopped and use `vpn-egress` manually.
- Backend and system-wide WireGuard use distinct identities. Keep `laptop` for
  the backend and provision a separate identity such as `laptop-system`.

## Work

1. Replace shell aliases with packaged commands or equally testable adapters
   while preserving the explicit sudo runtime boundary. No sudo in Home Manager
   activation and no host interface created automatically at login.
2. Serialize the transition. Interrupt/select blocked, run `wg-quick`, verify
   expected interface/routing structure, then select its bound egress. Down uses
   the inverse safe order. Do not expose the blocking choice as an everyday UI.
3. Specify and test rollback for command failure, partial interface creation,
   selector failure, backend restart, interface disappearance and reboot. Restore
   the previous healthy state when possible; otherwise remain blocked and print
   exact recovery/status instructions.
4. Structural checks establish ownership/readiness. Run a TCP/UDP/DNS diagnostic
   afterward, but do not define tunnel existence solely by one public endpoint.
5. Detect/refuse collisions across every active backend and per-app identity.
   Unknown external policy routing is reported honestly, never treated as proof
   of safety.

## Acceptance

- Both up/down and repeated/concurrent invocations are idempotent or fail with
  actionable state; two managed tunnels cannot be active through this interface.
- Local consumers remain running across transitions and reconnect afterward;
  seamless preservation of existing calls/sockets is not required.
- Missing or removed interfaces and all injected partial failures fail closed,
  never through the ordinary uplink.
- Host routes/resolver return to their prior state after down and rollback.
- Fixture tests precede a staging live test using a disposable, uncommitted
  system identity/server peer. Host activation remains a separate approval gate.
