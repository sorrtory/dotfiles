# 01 — Theme core, proven in WezTerm

Type: task
Status: ready-for-agent
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

- [ ] The activation package builds for all three themes, transparency on and
      off.
- [ ] A palette with a role deleted fails evaluation with a message naming it.
- [ ] An operator override for WezTerm, both as a hex and as a role remap,
      shows up in WezTerm, and the remap follows a theme switch.
- [ ] Gruvbox and autumn-glass WezTerm match today's WezTerm where the spec
      says they should.
- [ ] On the VM, switching the theme prints the hint with WezTerm under "live";
      a switch that changes nothing prints no hint.

## Comments
