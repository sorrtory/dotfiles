# 09 — Canonical docs and cleanup

Type: task
Status: claimed
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

- [x] No canonical doc still says Rewaita's Gruvbox preset is the baseline.
- [x] No hand-made theme file remains that a generated one replaces.
- [ ] The spec's Definition of done holds.

## Comments

2026-09-22: `configs/ayugram/` removed — the hand-made Autumn Glass theme, its
source directory and `build.sh`, whose `zip -qX colors.tdesktop-theme
background.*` was the same packing the Telegram activation step does. The
comments that pointed at it (`modules/theme/telegram-keys.nix`, README's
Telegram section) now name it as history rather than a path. Telegram's
theming also moved out of `modules/programs/vpnized-apps` into
`modules/theme/telegram.nix`, behind `dotfiles.theme.telegram.enable`, which
the AyuGram branch sets: none of it was about the VPN. The remaining
acceptance items (DECISIONS, CONTEXT, removing `.scratch/themes/`) are still
open.

2026-09-23: `docs/DECISIONS.md` now records the repository palette as source
of truth, Rewaita as a consumer, stable names, overrides, transparency, and
the reason for skipping Stylix. `CONTEXT.md` defines the theme vocabulary;
README's existing Themes section now includes Terminus. The remaining spec
checks need normal-use verification on the current host and staging VM as
applicable. Ticket 10 remains
upstream-blocked and will move to its own effort when this one closes.
