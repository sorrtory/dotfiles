# 04 — Add the `sops` tool and document the foundation

Status: resolved
Blocked by: 01

## Goal

Make the foundation usable and described. `docs/SOFTWARE.md` already lists
`sops` as a "Planned Home Manager package for the SOPS foundation / Not
implemented" — this is the slice that implements it.

## Work

1. Add `sops` to `modules/packages.nix` as a global user tool. It is a
   standalone tool, not owned by a program module, so `packages.nix` is the
   right home per the package policy in `docs/DECISIONS.md`.
2. Update the `sops` row in `docs/SOFTWARE.md` to point at its implementation,
   matching the existing row format.
3. In `docs/DECISIONS.md` under "Secrets and authentication", record what this
   slice decided, not what it did: that `.sops.yaml` is the single source of
   truth for the public recipient and why (it is what encryption actually
   reads); that the sops-nix Home Manager module consumes the recovered
   identity at `~/.config/sops/age/keys.txt` and never generates one; and that
   `secrets/` is mechanically enforced as ciphertext-only rather than by
   convention.
4. Update the `modules/secrets.nix` line in the `AGENTS.md` project map so it
   no longer reads "eventually".
5. Check whether `README.md`'s fresh-machine table still describes what phase
   04 does now that activation is secret-bearing. Update it only if it is
   actually wrong; do not restate the contract there.

## Constraints

- Documentation links to the canonical source rather than duplicating it, per
  `docs/agents/domain.md`. `docs/DECISIONS.md` owns the decision; other
  documents point at it.
- Record decisions and their reasoning, not a changelog of the diff.

## Acceptance

- No document still describes the SOPS foundation as planned or unimplemented.
- `docs/SOFTWARE.md`'s `sops` row links to `modules/packages.nix`.

## Answer

Implemented. `sops` 3.13.3 is a global user tool and appears in the built
profile at `home-path/bin/sops`.

Two judgement calls beyond the literal work list:

- The catalog's `age` row also claimed to be planned for this slice, which the
  acceptance criterion ("no document still describes the SOPS foundation as
  planned") covers. Rather than add a package nothing needs, the row now
  records where age actually comes from: the recovery app's own closure, which
  must carry it because recovery runs before Home Manager exists. If age turns
  out to be wanted on `PATH` for manual identity work, that is a separate,
  deliberate addition.
- `README.md` was left unchanged. Its phase-04 row does not claim to handle
  secrets, and no secret is materialized yet, so there was nothing wrong to fix.
