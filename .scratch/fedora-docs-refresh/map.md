# Fedora documentation cutover

Bring the documentation up to date with Fedora as the current host and Home
Manager as an established user environment, without rewriting historical
Ubuntu verification or weakening the host/user ownership boundary. See
[spec.md](spec.md) for the fixed distinctions.

## Frontier

Ticket 01.

## Tickets

- [01: Audit stale platform and migration claims](issues/01-audit-stale-claims.md) — ready-for-agent.
- [02: Update the canonical platform narrative](issues/02-canonical-platform-narrative.md) — ready-for-agent; blocked by 01.
- [03: Align operator and staging documentation](issues/03-operator-and-staging-docs.md) — ready-for-agent; blocked by 01 and 02.
- [04: Verify the documentation cutover](issues/04-verify-docs-cutover.md) — ready-for-agent; blocked by 03.

## Order

Inventory first so platform-specific history is not changed by search and
replace. Update canonical vocabulary and decisions before editing operational
guides. Finish with repository-wide consistency and public-interface checks.

## Context

- The operator now runs Fedora with this Home Manager environment active.
- There is currently no staging VM installed.
