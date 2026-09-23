# 13 — Terminus

Type: task
Status: claimed
Blocked by: 01

## What to build

Sublime's editor follows the palette; the terminal inside it does not.
`configs/sublime-text/Terminus.sublime-settings` carries Gruvbox hexes
written by hand, and `modules/programs/sublime-text.nix` deploys it as an
out-of-store symlink beside the generated color scheme. Under any palette but
Gruvbox the integrated terminal is simply the wrong theme — today, under
autumn-leaves, a copper editor with a Gruvbox terminal in it.

The file's own comment says its colors came from `configs/wezterm/wezterm.lua`
and `Gruvbox Rewaita.sublime-color-scheme`. Both moved on: WezTerm reads the
generated theme file now, and ticket 04 deleted the Rewaita scheme. The
settings are the last copy of a palette nothing else still holds.

- `user_theme_colors` generated from the roles and the ANSI set, the way
  WezTerm's `ansi`/`brights` already are.
- Terminus registered in `dotfiles.theme.apps` with whatever `apply` its
  reload behavior turns out to support.
- The two deliberate choices in the current file preserved as Gruvbox
  `overrides`, not baked into the generator: the soft `#32302f` background
  and the `#fffaeb` text, which are the same pair ticket 04 already moved into
  `overrides.sublime-text`.

## Notes

- Terminus names the yellow slot `brown` and the brights `light_*`, so the
  generator cannot just map role names across; it needs a small key table the
  way `telegram-keys.nix` does.
- The current file maps the eight normal colors to Gruvbox's *bright*
  variants and repeats them in `light_*`, matching how WezTerm was set up at
  the time. WezTerm now gives `ansi` the normal set and `brights` the bright
  set, so this is a behavior change to make deliberately rather than carry
  over: decide whether Terminus gets the true 16 or keeps the doubled-bright
  look, and record which.
- Every palette is validated to export all sixteen ANSI colors
  (`requiredAnsi` in `modules/theme/default.nix`), so the data is already
  guaranteed present.
- `Terminus View.sublime-settings` sits beside it in the same `genAttrs` list
  and may hold colors too; check before assuming one file is the whole job.

## Acceptance

- [ ] Each palette renders a Terminus scheme; the integrated terminal's
      visual result awaits host activation.
- [ ] A switch writes Terminus's watched settings file and its theme watcher
      regenerates the hidden color scheme; the open-view result awaits a switch.
- [x] A Terminus override in `home.nix` reaches the terminal like any other
      app's.
- [x] Gruvbox still renders the soft background and bright text the hand-made
      file chose.

## Comments

**2026-09-23 — found while reviewing ticket 12.** The zsh work argued that a
prompt in named colors "follows the theme in WezTerm and nowhere else." That
is literally true, and Terminus is the reason it is worth saying: it is the
other terminal in this configuration, and its sixteen colors are frozen. Once
12 lands, the generated prompt will be the only correctly themed thing inside
Sublime's terminal, which is how this was noticed.

## Answer

2026-09-23: `modules/programs/sublime-text.nix` writes six terminal UI
colors and all sixteen ANSI slots from `forApp "terminus"`. The normal slots
take the normal ANSI set and `light_*` takes the bright set; this replaces the
old doubled-bright mapping. Gruvbox preserves its hand-chosen soft background
and brighter text as palette overrides. `Terminus View.sublime-settings` only
sets a font and stays native. The generated settings use the theme live-file
copy path, and Terminus's installed `terminus/theme.py` watches
`user_theme_colors` and regenerates its hidden color scheme on changes.
`tests/theme_sublime_test.sh` checks all palettes, ANSI pairs, and an operator
override. `nix flake check`, the activation build, and the focused test pass.
The host view has not yet been switched or visually checked; normal-use
verification is still required before resolving this ticket.

The first version put the generator in a new, untracked Nix file. Git flakes
exclude untracked paths, so the operator's first `home-manager switch --flake .`
failed before activation. The generator now lives in the already tracked
Sublime module, allowing the working tree to evaluate without staging files.
The same switch then succeeded on the Fedora host. It wrote a regular
`Terminus.sublime-settings` with autumn-leaves colors (`#261814` background,
`#fbeada` foreground, distinct normal and bright reds). Sublime was not
running during that switch, so the integrated view still needs a normal-use
check after opening the application.

Terminus only regenerates an existing hidden scheme on a settings change while
it is running. On startup it checks whether the cached file exists, not whether
its colors match. The Sublime module now invalidates that cache before writing
new theme settings whenever the theme changes, so a closed application
regenerates it on the next launch too. The fix was activated on the Fedora host;
the stale cache is absent. Sublime's CLI accepted a generate-theme command but
did not start a session from the agent environment, so no generated scheme or
integrated view could be inspected yet.
