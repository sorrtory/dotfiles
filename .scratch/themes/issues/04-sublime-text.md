# 04 — Sublime Text

Type: task
Status: ready-for-agent
Blocked by: 01

## What to build

Sublime's color scheme is generated from the palette under the stable name
"Dotfiles" and recolors live on a switch.

- Preferences name the "Dotfiles" scheme permanently.
- The hand-made Gruvbox Rewaita scheme is replaced; its per-app choices
  become overrides where the operator still wants them.
- Sublime registers as "live" in the hint.

## Acceptance

- [ ] A switch with Sublime open recolors it without a restart.
- [ ] Each theme's scheme loads without Sublime console errors.
- [ ] A Sublime override in `home.nix` takes effect.

## Comments
