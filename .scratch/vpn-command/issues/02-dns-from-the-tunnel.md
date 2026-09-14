# 02 — Preserve private DNS and the secret boundary

Status: resolved
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

## Answer

Kept as designed through the refactor: `capture-config.sh` copies only UDP
resolver entries from the backend, and the payload bind-mounts a private
`resolv.conf` (capture's hijacked 172.31.255.2) and `nsswitch.conf` in its own
mount namespace. `tests/vpn_capture_config_test.sh` still covers key and
endpoint exclusion, missing DNS and atomic replacement.

On the freshly bootstrapped staging VM (2026-09-15): the running Vesktop main
process sees `nameserver 172.31.255.2` through `/proc/PID/root/etc/resolv.conf`
while the host keeps systemd-resolved's stub file; `vpn getent hosts
discord.com` resolves through capture; `vpn curl` HTTPS to Discord returns 200
with tunnel egress different from direct egress. No resolver file on the host
was modified.
