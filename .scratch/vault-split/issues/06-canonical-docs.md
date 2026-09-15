# 06 — Record the split in canonical docs

Status: ready-for-agent
Blocked by: 03

## Goal

Make the canonical docs describe two vaults, so the recovery design does not
still say the recovery vault is the operator's main database.

## Work

1. `CONTEXT.md`: redefine **Recovery vault** as the small vault holding the
   fixed list, and add **Daily vault** and its key file.
2. `docs/DECISIONS.md`, "Secrets and authentication": record the split, that the
   recovery vault never takes a key file, and why the key file is delivered by
   sops-nix.
3. `docs/MIGRATION.md`: fix the "main KeePassXC vault" wording in slice 2 and in
   the fresh-machine flow.

## Constraints

- The recovery repository README is the source of truth for the fixed list.
  Link or summarize it rather than keeping a second copy that can drift.

## Acceptance

- No doc calls the recovery vault the operator's main database.
- `tests/*.sh` still pass.
