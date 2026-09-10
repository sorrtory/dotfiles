# Native program configurations

Neovim, tmux, and Yazi: three readable native configs the operator edits
often, each depending on plugin assets the legacy manager restored. One spec
answers the shared mechanism question; the tickets apply it. See
[spec.md](spec.md).

## Tickets

- [01: Neovim](issues/01-neovim.md) — ready-for-agent.
- [02: tmux](issues/02-tmux.md) — ready-for-agent.
- [03: Yazi](issues/03-yazi.md) — ready-for-agent.
- [04: Documentation corrections](issues/04-documentation.md) — ready-for-agent; blocked by 01, 02, 03.

## Context

- `docs/MIGRATION.md` §10 to §12, promoted from "Additional candidates".
- The settled mechanism: configuration stays native and live-editable through
  `mkOutOfStoreSymlink` for all three; plugin ownership is decided per program.
  Nix owns tmux's three and Yazi's one; `lazy.nvim` and mason keep Neovim's
  sixteen. This is two specific judgments, not a general rule.
- The obligation that decision creates is ticket 01's real work: ten of the
  sixteen language servers Neovim declares are npm packages, so Node.js
  becomes a global user tool and the `fnm` shim in `init.lua` is deleted.
- Tickets 01 and 02 each own half of one feature — `Ctrl+h/j/k/l` navigation
  works only when both the tmux `is_vim` bindings and the Neovim plugin are
  present.
- `prefix + Ctrl+d` is broken on the current host before this effort touches
  anything; ticket 02 fixes it as a side effect of retiring TPM.
- Kitty, Hyprland, Wofi, dunst, tmuxinator, Obsidian, `.zshrc2`, and the
  `backups/` snapshots were reviewed and deliberately dropped, not deferred.
