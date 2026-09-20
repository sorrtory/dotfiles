# 01 — Theme core, proven in WezTerm

Type: task
Status: resolved
Blocked by: None (can start immediately)

## What to build

The operator sets the theme and the transparency switch in `home.nix`, runs
`home-manager switch`, and WezTerm recolors live. Activation prints the
switch hint. This is the tracer bullet: every later ticket plugs an app into
what it builds.

- The theme and transparency options, and the operator override layer.
- Palette files for gruvbox, autumn-glass and onedark, exporting the semantic
  roles and 16 ANSI colors (spec: Palette model). Gruvbox takes Rewaita's
  Gruvbox Medium hexes; autumn-glass takes the Autumn Glass hexes Spotify
  carries today plus the brighter text and bright-ANSI tweak WezTerm carries
  today; onedark takes Rewaita's One Dark palette.
- Override resolution (global → theme's app override → operator), accepting
  hexes and role functions, and the transparency alpha table.
- An evaluation error naming the theme and role when a required role is
  missing.
- WezTerm colors, tab bar and opacity from the resolved palette.
- The hint: a registry in which each app declares how it takes a change
  (live, restart, one-time setup, plus an optional check), and one combined
  notice printed only when the theme or transparency changed.

## Acceptance

- [x] The activation package builds for all three themes, transparency on and
      off.
- [x] A palette with a role deleted fails evaluation with a message naming it.
- [x] An operator override for WezTerm, both as a hex and as a role remap,
      shows up in WezTerm, and the remap follows a theme switch.
- [x] Gruvbox and autumn-glass WezTerm match today's WezTerm where the spec
      says they should.
- [ ] On the VM, switching the theme prints the hint with WezTerm under "live";
      a switch that changes nothing prints no hint.

## Comments

## Answer

Built in `modules/theme/` (options, resolution, notice) with palettes in
`modules/theme/palettes/`; `tests/theme_test.sh` covers the first four checks.

- Apps read `config.dotfiles.theme.forApp "<app>"`: roles, the 16 ANSI colors
  (`black` … `brightWhite`) and `alpha.{window,surface,popup}`. Overrides are
  merged with `recursiveUpdate`, so `{ alpha.window = 0.95; }` works;
  transparency off forces every alpha to 1.
- Apps register in `dotfiles.theme.apps.<app>` (`apply` = live, restart or
  relogin; optional `restartNote`, `setup`, `check`). A step that fails to
  apply live moves its app with `dotfilesThemeApply[<app>]=relogin`; it must
  run after `dotfilesThemeInit`. The notice is the last activation step.
- Apps that watch their files use `dotfiles.theme.liveFiles`: activation
  copies them under `~/.local/share/dotfiles/theme/` as real files rewritten
  in place, because a Home Manager symlink swap does not reach a watcher.
  Verified: a WezTerm mux server reloads its config on that rewrite.
- WezTerm's scheme is named "Dotfiles"; without the theme file it falls back
  to its bundled GruvboxDark.
- autumn-glass's `text` is WezTerm's former #fbf1c7, as the ticket asks.
  Tickets 06–08 that must reproduce the stock #f6e9da should add an
  `overrides.<app>.text` in that palette.
- Gruvbox no longer has WezTerm's contrast tweak (spec: stock Gruvbox).

Not done: the VM run. The notice was checked by running the theme's
activation steps against a scratch home (first switch prints it, unchanged
prints nothing, a transparency change prints it again), not a real switch.
