# Firefox under Nix

Take Firefox off the snap so its profile is predictable, its preferences and
extensions can be declared, and sops-rendered secrets are readable by it. See
[spec.md](spec.md) for the measured confinement limits that motivate it.

## Tickets

- [01: Replace the Firefox snap with a Nix-managed Firefox](issues/01-replace-the-firefox-snap.md) — needs-triage.
- [02: Declarative preferences and extensions](issues/02-declarative-profile.md) — needs-triage; blocked by 01.
- [03: Encrypt the PAC file and deliver it to the browser](issues/03-encrypt-and-deliver-the-pac.md) — needs-triage; blocked by 01.
- [04: Record the Snap sourcing policy](issues/04-snap-sourcing-policy.md) — needs-triage; blocked by 01.

## Context

- Split out of the completed local-proxy effort, retained in Git history.
  Its Snap-specific Firefox ticket was superseded by this effort. The current
  proxy and PAC settings are in [README.md](../../README.md#local-proxy) and
  `configs/firefox/user.js`.
- The old Snap-profile activation script was never installed; this effort
  still owns the decision to package Firefox and manage its native profile.
- Ticket 01 also carries the APT preferences pin, and ticket 04 the Snap
  sourcing policy. Both were settled in the grilling session that promoted
  this effort into `docs/MIGRATION.md` as slice 14: `snapd` stays as host
  infrastructure, and nothing this repository declares comes from Snap.
