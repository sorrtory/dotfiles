# 07 — Exclude concurrent owners of the VPN identity

Status: ready-for-agent
Priority: P1

## Evidence

Review at 1e75b0f: modules/programs/zsh.nix checks sing-box only before
vpn-up. Following its advice (stop backend, vpn-up), then launching Vesktop
starts vpn-capture, whose Wants starts sing-box again with the same identity.
This is a static service-dependency finding, not a live collision reproduction.

## Work

Enforce exclusion in both directions for supported entry points, including
automatic backend startup, restart and managed application launch. Cover
concurrent starts rather than relying solely on a check-then-start sequence.
Keep this fix scoped to the current single identity: no automatic egress
switching, new profiles or system-wide routing design. Do not introduce sudo
into Home Manager activation or silently stop an existing tunnel.

## Acceptance

- Both startup orders and concurrent attempts cannot create two supported
  clients using the same peer; refusal is actionable.
- Test backend autostart/restart and Vesktop launch while whole-host mode owns
  the identity, using mocks or an isolated staging fixture rather than causing
  a real shared-peer collision.
- Ordinary app VPN and whole-host use separately still work.
- Document the supported guard boundary; arbitrary external clients are not
  claimed to be controlled by these helpers.
