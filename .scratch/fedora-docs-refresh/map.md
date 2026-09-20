# Fedora documentation cutover

Bring the documentation up to date with Fedora as the current host and Home
Manager as an established user environment, without rewriting historical
Ubuntu verification or weakening the host/user ownership boundary. See
[spec.md](spec.md) for the fixed distinctions.

## Frontier

None. Every ticket is resolved; this directory is ready to be removed in the
completion commit.

## Tickets

- [01: Audit stale platform and migration claims](issues/01-audit-stale-claims.md) — resolved.
- [02: Update the canonical platform narrative](issues/02-canonical-platform-narrative.md) — resolved.
- [03: Align operator and staging documentation](issues/03-operator-and-staging-docs.md) — resolved.
- [04: Verify the documentation cutover](issues/04-verify-docs-cutover.md) — resolved.

## Order

Inventory first so platform-specific history is not changed by search and
replace. Update canonical vocabulary and decisions before editing operational
guides. Finish with repository-wide consistency and public-interface checks.

## Context

- The operator now runs Fedora with this Home Manager environment active.
- A staging VM exists after all. The first, `silverblue43`, was Fedora 43
  Silverblue and could not bootstrap at all on an rpm-ostree image; the operator
  replaced it with `fedora` at `z@192.168.122.21`, Fedora 44 Workstation on
  GNOME/Wayland, where `host-deps` and `nix` are verified. Recorded in
  `docs/STAGING.md`; rpm-ostree support remains unstarted with no effort opened.
- Ticket 04's `## Answer` lists the durable facts that must survive this
  directory's removal.
