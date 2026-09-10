# VPN command

Put one application on the `extra` WireGuard tunnel, leaving the host alone,
and never leave the operator believing an application is tunneled when it is
not. See [spec.md](spec.md) for the behavior baseline and what the legacy
script does today.

## Tickets

- [01: Namespace lifecycle](issues/01-namespace-lifecycle.md) — ready-for-agent.
- [02: DNS from the tunnel, and never from the host](issues/02-dns-from-the-tunnel.md) — ready-for-agent; blocked by 01.
- [03: Run the payload as the invoking user](issues/03-run-as-the-user.md) — ready-for-agent; blocked by 01, 02.
- [04: Refuse when the application is already running](issues/04-refuse-to-lie.md) — ready-for-agent; blocked by 03.
- [05: Verify the launcher families, and the leaks](issues/05-verify-the-launcher-families.md) — ready-for-agent; blocked by 04.
- [06: Package it, expose it, document it](issues/06-package-and-document.md) — ready-for-agent; blocked by 05.

## Context

- `docs/MIGRATION.md` §7, and `docs/DECISIONS.md` on scripts and privileged
  networking: Bash source under `scripts/bin/`, packaged with
  `writeShellApplication`, payload as the invoking user.
- The legacy script is `~/Documents/scripts/vpn.sh`, 686 lines, pointing at
  `/etc/wireguard/extra.conf` — a path the WireGuard slice deliberately
  stopped using. The configuration now arrives decrypted at
  `~/.config/sops-nix/secrets/wireguard/extra.conf`.
- `modules/secrets.nix` already states this command's purpose: `extra` is
  "shared across machines and used to put a single application on the other
  side rather than the host."
- `vpn-up` and `vpn-down` in `modules/programs/zsh.nix` are a different thing:
  they tunnel the whole host on `laptop`. Ticket 06 settles the naming.

## What decides the design

The operator wants any command to work, with the three launcher families
installed here — Electron from `/usr/bin`, snaps, Flatpaks — actually working
rather than nominally supported.

An application already running outside the tunnel must produce a refusal, not a
window. Electron's `SingletonSocket`, `snap-confine`'s shared mount namespace,
and Flatpak's instance sharing all turn a second launch into a message to the
first process, so the window appears and the traffic does not move. Success and
silent no-op look identical, which is why detecting it is part of the feature.

DNS comes from the tunnel's own configuration, and nothing outside
`/etc/netns/<ns>/` is written. The legacy mode that repoints the host's
`/etc/resolv.conf` is dropped, not migrated: it is the one failure that
outlives the command.

## Why not sing-box

Asked directly, and answered in the spec. sing-box's proxy is opt-in per
connection — UDP, QUIC, WebRTC, non-HTTP protocols, and local name resolution
all bypass it, and an application that ignores the setting cannot be made to
honor it. A namespace is unconditional: a process inside has no route anywhere
except the tunnel. sing-box's capture-everything mode wants `CAP_NET_ADMIN`, a
TUN device, and host-wide routing changes in order to exempt most traffic
again, which is both more invasive and what §13 rules out. The two are
complementary, and `docs/DECISIONS.md` already draws that line.

## Verification will need hands

Every meaningful check is privileged and needs a desktop session. The staging
VM has one but no usable GPU, and privileged commands there have been refused
by the sandbox before. Plan for part of ticket 05 to be handed to the operator
with exact commands.
