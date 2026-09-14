# 01 — Several identities, per-app identity and protocol switching

Status: needs-triage
Blocked by: vpn-command/06

## Goal

Make changing or adding a VPN identity a small, explicit edit, including a
different protocol and a different identity per application.

## Sketch

1. Turn `dotfiles.vpn.identity` into a set of named identities, keeping a single
   default so the common case stays one line.
2. The backend exposes one outbound and one local SOCKS inbound per identity,
   still one sing-box backend process.
3. Capture becomes a templated `vpn-capture@<identity>.service`, one namespace
   per identity in use, each started on demand.
4. Managed apps choose an identity (`dotfiles.vpnizedApps.<app>.identity`);
   the generic command accepts `vpn --identity NAME PROGRAM`.
5. The backend generator dispatches on the ciphertext's protocol. Capture and
   launchers must not change for a protocol swap.

## Constraints

- Each identity is still exclusive to one running machine.
- No direct fallback when a chosen identity is down.
- Keep the capture config free of keys, as today.
