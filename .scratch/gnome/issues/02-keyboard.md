# 02 — Keyboard layouts, Alt+Shift and Caps Lock

Type: task
Status: ready-for-agent

## Goal

Declare the input sources and XKB options in `modules/desktops/gnome.nix`.

## Work

1. Set `dconf.settings."org/gnome/desktop/input-sources"`:
   `sources` is the `us` and `ru` tuples, and `xkb-options` is
   `[ "grp:alt_shift_toggle" "caps:escape_shifted_capslock" ]`.
2. Leave `switch-input-source` at its default (`<Super>space`).
3. Record in `docs/DECISIONS.md` that the user environment owns
   `input-sources`, while `/etc/default/keyboard` stays host-owned.

## Constraints

- No `sudo`, and nothing written under `/etc`.
- `xkb-options` is replaced as a whole list. Declare every option to keep.

## Acceptance

- `nix flake check` and the activation package build succeed.
- The generated dconf INI in the activation package holds exactly these two
  keys.
- On a GNOME VM or the new PC: Caps Lock gives Escape, Shift+Caps Lock
  toggles Caps Lock, and Alt+Shift and Super+Space both switch us⇄ru. Check
  this in a terminal and in Neovim.

## Comments
