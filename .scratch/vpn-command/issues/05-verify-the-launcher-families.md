# 05 — Verify everyday Vesktop and failure behavior

Status: claimed
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

## Comments — Staging evidence, 2026-09-15

Fresh VM from the `ssh-server` snapshot, full bootstrap as `staging`
(docs/STAGING.md), reboot into the autologin session.

Passed: direct vs tunneled egress differ (IPv4 212.118.38.195 via the tunnel);
IPv6 is captured too (`vpn curl -6` exits 2a0d:8480:3:10b::100 while the VM
itself has no IPv6); DNS confinement (ticket 02); stdin through `vpn`;
last-app exit stops capture and removes its runtime; ten back-to-back launches
and repeated `vpn curl`; relaunching Vesktop right after quitting; backend
restart keeps capture's namespace and restores HTTPS without restarting
Vesktop; killing capture ends Vesktop; a 45 s link drop recovers 5 s after the
link returns with no sing-box restart and Vesktop still in capture. The host
capture test (`tests/manual/vpn_capture.sh`) passes every stage, including the
new back-to-back stage.

The operator logged in on the rebuilt staging setup and confirmed a working
voice call through the managed launch.

Not yet evidenced: a change to a different network or address, and a real
guest suspend-to-RAM. Host checks (GPU, the host's own
policy) belong to host activation, which needs operator approval.

A 60 s VM pause (`virsh suspend`/`resume`, a stand-in rather than a guest
suspend-to-RAM) recovered HTTPS through capture 5 s after resume, with no
sing-box restart and Vesktop still running.

## Comments — Remaining recovery gate, 2026-09-15

Keep this open until network/address change and real suspend-to-RAM have
separate evidence. For each, record recovery time, whether intervention was
needed, capture/app survival, tunneled versus direct egress, DNS confinement,
and unchanged host routes/resolver. VM pause is not a substitute for guest
suspend. Record unavailable coverage explicitly rather than marking it passed.
