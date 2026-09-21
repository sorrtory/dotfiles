# 09 — Canonical docs and cleanup

Type: task
Status: ready-for-agent
Blocked by: 02, 03, 04, 05, 06, 07, 08, 11

## What to build

The theme system is recorded in the canonical docs, and leftovers from
per-app theming are gone.

- DECISIONS: the palette as the source of truth, Rewaita as a consumer
  (replacing its baseline entry), stable names, overrides, and why no Stylix.
- CONTEXT: Theme, Palette, Role, Override, Transparency.
- README: one Themes section covering both switches, the hint, and each
  one-time step.
- Hand-made per-app theme files and comments that point at them are removed.
- The `.scratch/themes/` directory is removed in the completion commit, per
  the issue-tracker convention; ticket 10, if still open, moves to its own
  effort first.

## Acceptance

- [ ] No doc still says Rewaita's Gruvbox preset is the baseline.
- [ ] No hand-made theme file remains that a generated one replaces.
- [ ] The spec's Definition of done holds.

## Comments
