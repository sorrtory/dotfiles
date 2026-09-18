# 04 — Verify the documentation cutover

Status: ready-for-agent
Blocked by: 03

## Goal

Prove that the documentation tells one accurate story after the Fedora cutover.

## Work

1. Repeat the audit queries from ticket 01 and review every remaining match in
   context.
2. Check links among README, canonical documents, software catalog, and staging
   guide.
3. Run the repository's documentation-facing and general public-interface
   tests appropriate to documentation-only changes.
4. Confirm the diff contains no implementation, invented Fedora staging result,
   or accidental rewrite of unrelated user changes.
5. Append commands and results under `## Answer`, then identify the durable
   facts that should remain in canonical docs when this scratch effort is
   removed.

## Constraints

- The working tree may contain unrelated operator changes. Do not fold them
  into this milestone or revert them.
- Passing text searches is not enough; remaining Ubuntu, activation, and
  migration language must be reviewed semantically.

## Acceptance

- Canonical and operational documents agree on the current Fedora baseline.
- Ubuntu-specific history and guidance are preserved and correctly labelled.
- Home Manager is described as established without weakening the host-owned
  system boundary.

## Comments
