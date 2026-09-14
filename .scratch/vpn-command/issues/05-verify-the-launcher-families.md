# 05 — Verify everyday Vesktop and failure behavior

Status: ready-for-agent
Blocked by: 04

## Goal

Prove the selected module supports everyday Vesktop, not just CLI/STUN probes.

## Work

1. Test the generated terminal, desktop and URL launch paths; inspect actual
   Vesktop processes and descendants for namespace/user/capability correctness.
2. Verify a real operator-assisted voice call, UDP traffic, microphone/playback
   and required desktop integration. Distinguish automated STUN success from
   voice-call evidence; do not join calls or send messages without the operator.
3. Check distinct direct/tunneled egress, DNS confinement and IPv6 no-escape.
   If the peer has no IPv6 Internet access, it must fail closed. Local IPv6 echo
   success alone does not prove remote IPv6 connectivity.
4. Repeat backend stop/restart, capture crash, simultaneous launch, last-app exit
   and fresh launch after cleanup. The shared local proxy must remain usable.
5. Test network loss, resume and connection changes. Investigate reproduced
   failures before adding recovery machinery; process-active is not tunnel-healthy.
6. Record host route/rule/resolver invariants and exclusive identity selection.
   Never collide with the host legacy laptop peer or staging desktop-ubuntu peer.
7. Use staging within its namespace-policy and GPU limits. Do not relax host or
   VM security policy silently. Obtain approval for required host runtime tests
   or activation and state clearly what staging could not establish.

## Acceptance

- Saved regressions plus actual Vesktop voice evidence cover the selected flow.
- Other applications retain ordinary connectivity, with no host-wide capture.
- Unsupported prerequisites and unverified cases are documented honestly.
- No Snap/Flatpak/general launcher-family coverage is required for this slice.
