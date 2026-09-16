# 09 — Record the private vault in canonical documentation

Status: ready-for-agent

Blocked by: 01, 05, 06, 07, 08

## Goal

The decisions that outlive this effort move into the documentation the
repository actually keeps, and the scratch directory goes away.

## Work

1. Record in the decision log what is durable: gocryptfs over a LUKS image; the
   path rule and the absence of a named-vault registry; explicit unlocking with
   no automatic mount, no timer and no escalation; what a successful lock
   verifies and what it cannot promise; the FUSE prerequisite as host-owned;
   and that backups are a separate milestone rather than something this
   provides.
2. Check the vocabulary entries for the private vault and the knowledge
   database against what was built, and correct them if the implementation
   moved. Do not restate the tickets there.
3. Remove `.scratch/private-vault/` in the completion commit, as the tracker's
   completion rule requires. Git history keeps the spec and the tickets.

## Constraints

- Canonical documentation records decisions and ownership, not a changelog of
  how the tickets went.
- Anything still genuinely undecided is not quietly written down as settled. It
  either gets decided here or is named as open.
- Backup design stays out. It is its own milestone covering the vault, the
  archive and other user data.

## Acceptance

- The decision log states the vault's ownership boundary and the honest limit
  of its lock guarantee.
- The vocabulary matches the shipped commands.
- The scratch directory is gone and no documentation links into it.
