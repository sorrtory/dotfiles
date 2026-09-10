# 03 — Encrypt the PAC file and deliver it to the browser

Status: needs-triage

Blocked by: 01

## Goal

Move `proxy.pac` out of a plaintext path in `~/Documents/secrets/` and into
repository ciphertext, delivered somewhere a Nix-managed Firefox can read.

## Why it waits for 01

The PAC contains no credentials — the only addresses in it are
`127.0.0.1:1080` and `0.0.0.0:0` — so it is publishable in the secrets sense.
It is not publishable in the personal sense: it is a self-discipline blocklist
with a weekday exception, and this repository is public. So it becomes
ciphertext.

sops-nix renders secrets to `%r/secrets.d` with a stable symlink under
`~/.config`, and `sops.secrets.<name>.path` produces a symlink rather than a
copy. A confined Firefox can read none of those. De-snapping is what makes
the ordinary sops delivery path usable.

## Work

1. Encrypt `proxy.pac` to `secrets/proxy.pac` using the `.sops.yaml`
   recipient, `format = "binary"`, matching the WireGuard convention.
2. Point `network.proxy.autoconfig_url` at the decrypted path.
3. Remove the plaintext copy from `~/Documents/secrets/`, and confirm nothing
   else references that path.
4. Confirm Firefox re-reads the PAC after a reboot, when the runtime directory
   has been recreated and the sops-nix user service has re-rendered it.

## Constraints

- The PAC stays the routing policy engine. Do not move its rules into
  sing-box route rules: sing-box has no time-based matcher, so the weekday
  exception has no equivalent short of a timer driving the Clash API, and the
  block list is browser-specific by nature.
- Verify the file mode sops-nix assigns is one Firefox accepts.

## Acceptance

- No plaintext `proxy.pac` outside the runtime directory.
- Proxy, direct and blocked domains all behave as before the move.
- Behavior survives a reboot with no manual step.
