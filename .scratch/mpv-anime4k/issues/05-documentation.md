# 05 — Documentation corrections

Status: claimed
Blocked by: 02, 03, 04

## Goal

Make the canonical documents describe what this slice actually built. Three of
them currently assert things that are now false.

## Work

1. `docs/DECISIONS.md`, "Package policy": it says *"Anime4K is expected to
   become a pinned local package rather than vendored shader files."*
   Nixpkgs carries `anime4k` 4.0.1, so working rule 3 — prefer Nixpkgs before
   writing local packages — applies. Replace the sentence with the decision
   actually taken and why the earlier expectation was superseded.
2. `docs/SOFTWARE.md`: update the `Anime4K`, `MPV`, and `MPV scripts` rows to
   name their real installation mechanism and link
   `../modules/programs/mpv.nix`.
3. `docs/SOFTWARE.md`: add rows for the three local script packages from
   ticket 03, so the catalog explains why they are local when the others are
   not.
4. `docs/MIGRATION.md` §8: confirm the text matches what shipped.

## Constraints

- Do not weaken the Nixpkgs-first rule to justify the local packages. The
  distinction is specific and worth stating plainly: the three local packages
  exist because Nixpkgs does not carry them, not because a local package was
  preferred.
- `flake.lock` remains authoritative for versions. Do not write version
  numbers into `SOFTWARE.md` rows.

## Acceptance

- No canonical document describes Anime4K as planned, pending, or local.
- Every MPV-related `SOFTWARE.md` row links to a file that exists.
- `tests/*.sh` still pass.

## Comments

`docs/DECISIONS.md` package policy: the sentence expecting Anime4K to become a
pinned local package is replaced by the decision actually taken — Nixpkgs
carries it, so working rule 3 applies — plus why the shader bindings changed
and why re-nesting the layout was rejected. The same paragraph now states the
narrow reason a local MPV script package is legitimate (Nixpkgs lacks it, or
the attribute of that name is a different script) so the Nixpkgs-first rule is
not weakened, and records the `mpv-cut` unfree entry.

`docs/SOFTWARE.md`: the `Anime4K`, `MPV`, and `MPV scripts` rows now name their
real mechanism and link `../modules/programs/mpv.nix`. Four rows were added,
one per local package, each linking its own file. No version numbers were
written into any row.

`docs/MIGRATION.md` §8 rewritten to describe what shipped, including the four
local packages and which two are load-bearing.

All `tests/*.sh` pass, `nix flake check` passes, and both staged gates
(`check-bootstrap-phases.sh`, `check-secrets.sh`) pass.
