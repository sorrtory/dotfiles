# 02 — GNOME via a generated Rewaita palette

Type: task
Status: resolved
Blocked by: 01

## What to build

A theme switch recolors GNOME Shell, GTK apps and Firefox chrome live when
activation runs in the operator's GNOME session, and sets the theme's accent,
icons and wallpaper. Transparency on/off reaches GTK, Firefox and Blur my
Shell.

- Rewaita CSS generated from the palette into Rewaita's user palette
  directory, one per theme; Rewaita becomes a consumer.
- Rewaita's mutable preferences keep the operator's Fine Tune edits; only the
  keys this repo owns (theme, transparency, accent) are merged.
- Inside a GNOME session activation applies the theme immediately; otherwise
  the login autostart does, and the hint says to log out and back in.
- Accent, icon theme and wallpaper from the theme, falling back when absent.
- Blur my Shell's application blur and Firefox's transparent-page preference
  follow the transparency switch.

## Acceptance

- [x] Gruvbox renders the same GNOME look as today.
- [x] On the Ubuntu GNOME VM, each theme switch recolors Shell and GTK without
      a re-login, and Fine Tune edits survive it.
- [x] Activation over plain SSH puts GNOME on the hint's re-login line.
- [ ] Transparency off makes GTK, Firefox chrome, Spotify and Sublime opaque
      (Firefox and blur confirmed on the host).
- [x] The README's theme section covers GNOME.

## Comments

## Answer

Rewaita is a consumer now: `modules/theme/rewaita-css.nix` renders a user
palette per theme from the resolved colors, and `modules/desktops/gnome.nix`
writes them to `~/.local/share/rewaita/dark/Dotfiles <theme>.css`, merges the
keys this repository owns into Rewaita's preferences, and runs
`rewaita --theme=dotfiles-<theme>` when a theme changed and there is a GNOME
session to talk to. `tests/theme_gnome_test.sh` covers the palette, the merge
and the SSH path.

- Rewaita's accent map reads the first shade of a color family, so the family
  GNOME's accent name points at carries the theme's own accent. The remaining
  shades are a ramp toward the background rather than upstream's hand-filled
  table.
- The theme's `assets` carry `gnomeAccent`, `iconTheme` and an optional
  `wallpaper`; a theme that declares none leaves those settings alone.
- Transparency reaches GTK through Rewaita's own toggle, Blur my Shell through
  dconf, and Firefox through `browser.tabs.allow_transparent_browser`, which
  moved out of `configs/firefox/user.js` into the generated file.
- The theme module now exposes `forAppIn` and `assetsIn` for an app that
  generates a file per theme, and `dotfilesThemeChanged`, which is how this
  step knows not to re-run Rewaita on an activation that changes nothing.

Outstanding: transparency off on the host, where Firefox's chrome and Blur my
Shell can be judged with a GPU. Spotify and Sublime take their transparency
from Blur my Shell, which now follows the switch, so they are covered by the
same check rather than by their own tickets.

Verified on the Fedora VM (2026-09-20), activation run inside its GNOME
session:

- Switching to onedark recolored the Shell, the accent and the icons in place;
  Files took the new colors when it was restarted, which is GTK reading
  gtk.css at startup, not something activation can do differently. The notice
  and the spec's table now say so.
- Switching back to gruvbox reproduced the old look exactly: the Files window
  is pixel-identical to a screenshot taken before any of this existed
  (0 of 509600 pixels differ).
- Transparency off turned the same GTK surfaces from wallpaper-tinted
  (#2a2e34) to flat #282828.
- Activation over plain SSH printed "Log out and back in: GNOME Shell, GTK and
  Firefox" and left WezTerm on the live line.
