# 05 — Documentation corrections

Status: ready-for-agent
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
