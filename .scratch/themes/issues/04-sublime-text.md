# 04 — Sublime Text

Type: task
Status: resolved
Blocked by: 01

## What to build

Sublime's color scheme is generated from the palette under the stable name
"Dotfiles" and recolors live on a switch.

- Preferences name the "Dotfiles" scheme permanently.
- The hand-made Gruvbox Rewaita scheme is replaced; its per-app choices
  become overrides where the operator still wants them.
- Sublime registers as "live" in the hint.

## Acceptance

- [x] A switch with Sublime open recolors it without a restart.
- [x] Each theme's scheme loads without Sublime console errors.
- [x] A Sublime override in `home.nix` takes effect.

## Comments

## Answer

`modules/theme/sublime-scheme.nix` renders the scheme and
`modules/programs/sublime-text.nix` writes it to
`~/.config/sublime-text/Packages/User/Dotfiles.sublime-color-scheme` as a live
file — an ordinary file rewritten in place, which is what Sublime's watcher
notices. Preferences name "Dotfiles" and never change again.

- `Gruvbox Rewaita.sublime-color-scheme` is deleted. Its two deliberate
  choices live on as the gruvbox palette's `overrides.sublime-text`: the soft
  #32302f background and the #fffaeb text, which is brighter than any Gruvbox
  shade because the window blur fades it.
- Syntax takes the semantic roles where they mean something and the brighter
  ANSI hues where the old scheme used a hue the roles do not name (purple for
  constants, aqua for tags and imports). Other scopes differ slightly from the
  old scheme — selection and the gutter foreground among them — which is the
  divergence the spec now allows.
- `dotfiles.theme.liveFiles` takes absolute paths now, rather than names under
  one directory, so an app that wants its theme inside its own configuration
  can have it there.

Verified on the Fedora VM (2026-09-20): with Sublime open on a file, a switch
to autumn-glass recolored it in place — editor background #323132 to #271b18,
gutter and line highlight with it — and the notice listed Sublime under
"Updated live". `tests/theme_sublime_test.sh` checks that every theme renders
valid JSON with colors Sublime accepts, that each theme paints its own
background, and that an override reaches the scheme.
