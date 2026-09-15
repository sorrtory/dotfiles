# 02 — Keyboard layouts, Alt+Shift and Caps Lock

Type: task
Status: resolved

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

## Answer

Landed in `modules/desktops/gnome.nix` (`org/gnome/desktop/input-sources`),
with the host/user keyboard split recorded in `docs/DECISIONS.md`.
`switch-input-source` stays at GNOME's default.

- **Host:** `nix flake check` passes, and the activation package builds. The
  dconf INI's `input-sources` section holds exactly `sources` (us, ru) and
  `xkb-options` (`grp:alt_shift_toggle`, `caps:escape_shifted_capslock`).
- **VM:** verified as described under Comments. Caps Lock gives Escape,
  Shift+Caps Lock toggles Caps Lock, and Alt+Shift and Super+Space both switch
  us⇄ru in a terminal and in Neovim.
- **Known quirk, kept by the operator on 2026-09-15:** turning Caps Lock on
  with Shift+Caps Lock also sends Escape. It matches the current PC's option
  and very likely its behavior today. Confirm on the new PC. If it bothers in
  normal use, `caps:escape` is the clean alternative, but it has no Caps Lock
  at all.

Not verified: the new PC under normal use.

## Comments

2026-09-15, agent, staging on the Ubuntu GNOME VM (GNOME 50.1, xkb-data 2.46-2),
after re-login. Keys were sent with `virsh send-key` into `cat > file` running
in Ptyxis, and the file bytes were read back:

- The declared keys read back exactly. The panel shows the `en` indicator.
- **Caps Lock alone** sends `ESC` (`\033`). In Neovim, a final Caps Lock left
  insert mode, so `:wq` saved the file.
- **Layout switching:**
  - `Alt+Shift` switches to ru (`у`, `к`), `Super+Space` switches back
    (`f`), and a second `Alt+Shift` returns to us (`g`).
  - The XKB toggle and GNOME's switcher stay in step: after an `Alt+Shift`,
    `Super+Space` goes back to us rather than skipping.
- **Shift+Caps Lock** toggles Caps Lock, but every press that turns it *on*
  also sends `ESC`. Presses that turn it off send nothing. Recorded as
  `^[X1x2^[X3x4`, the same with Left Shift, Right Shift and a 600 ms hold.
  In Neovim's insert mode, turning Caps Lock on therefore drops to normal mode
  first.
- **The keymap doesn't explain it.** Both the xkb-data source and the keymap
  compiled by `xkbcli` define `<CAPS>` as `TWO_LEVEL`
  `[ Escape, Caps_Lock ]` with `LockMods` on level 2. On paper, Shift+Caps
  Lock never yields Escape. The extra `ESC` appears between the compositor
  and the client, where Mutter's modifier ordering, IBus or GTK are all
  candidates. The current PC runs the same versions, so it very likely
  behaves the same today.
- **A fallback fails.** `['grp:alt_shift_toggle', 'caps:escape',
  'shift:both_capslock']`, set live on the VM and then restored, gave a clean
  `ESC` from Caps Lock and working layout switches. Pressing both Shifts never
  enabled Caps Lock (`x1x2x3x4`), most likely because `grp:alt_shift_toggle`
  and `shift:both_capslock` both define the Shift keys, and the later option
  wins.
