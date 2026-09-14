# 02 — Preserve private DNS and the secret boundary

Status: ready-for-agent
Blocked by: 01

## Goal

Retain verified tunnel DNS behavior while relocating and simplifying helpers.

## Work

1. Reuse the capture configuration generator: copy only backend DNS metadata,
   not WireGuard keys or endpoints. Preserve the selected backend resolver and
   fallback policy; do not introduce another WireGuard config parser.
2. Keep resolver and nsswitch overrides in the payload's private mount namespace.
   Verify supported distro resolver symlinks and avoid host resolver/session-bus
   shortcuts that would resolve app names outside the tunnel.
3. Preserve mode-private runtime files, atomic validation, redacted errors and
   cleanup that tolerates capture shutdown racing payload exit.
4. Adapt existing configuration tests to the new location, including missing
   DNS, invalid input, no key copying and no direct outbound.
5. Verify DNS through the real managed app launch path, not only a shell probe.

## Acceptance

- App DNS traverses capture and the tunnel.
- Host resolver files and symlink targets are unchanged before/after runs.
- No new dnsmasq, host resolver backup, environment dump or plaintext secret in
  the Nix store/logs.
- Cleanup and configuration tests retain their existing failure checks.
