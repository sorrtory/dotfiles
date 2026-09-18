# 02 — GNOME via a generated Rewaita palette

Type: task
Status: ready-for-agent
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

- [ ] Gruvbox renders the same GNOME look as today.
- [ ] On the Ubuntu GNOME VM, each theme switch recolors Shell and GTK without
      a re-login, and Fine Tune edits survive it.
- [ ] Activation over plain SSH puts GNOME on the hint's re-login line.
- [ ] Transparency off makes GTK, Firefox chrome, Spotify and Sublime opaque
      (Firefox and blur confirmed on the host).
- [ ] The README's theme section covers GNOME.

## Comments
