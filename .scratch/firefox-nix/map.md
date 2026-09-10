# Firefox under Nix

Take Firefox off the snap so its profile is predictable, its preferences and
extensions can be declared, and sops-rendered secrets are readable by it. See
[spec.md](spec.md) for the measured confinement limits that motivate it.

## Tickets

- [01: Replace the Firefox snap with a Nix-managed Firefox](issues/01-replace-the-firefox-snap.md) — needs-triage.
- [02: Declarative preferences and extensions](issues/02-declarative-profile.md) — needs-triage; blocked by 01.
- [03: Encrypt the PAC file and deliver it to the browser](issues/03-encrypt-and-deliver-the-pac.md) — needs-triage; blocked by 01.

## Context

- Split out of [`singbox-local-proxy`](../singbox-local-proxy/map.md), which
  needed Firefox pointed at a proxy but could not encrypt the PAC while snap
  confinement denied every path sops-nix renders to.
- Ticket 02 deletes the interim activation script that
  `singbox-local-proxy` ticket 02 introduces.
