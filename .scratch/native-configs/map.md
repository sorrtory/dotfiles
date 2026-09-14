# Native program configurations

Neovim, tmux, and Yazi: three readable native configs the operator edits
often, each depending on plugin assets the legacy manager restored. One spec
answers the shared mechanism question; the tickets apply it. See
[spec.md](spec.md).

## Tickets

- [01: Neovim](issues/01-neovim.md) — claimed; implemented and checked on the host, awaiting VM activation.
- [02: tmux](issues/02-tmux.md) — claimed; implemented and checked on the host, awaiting VM activation.
- [03: Yazi](issues/03-yazi.md) — claimed; implemented on the host, `Alt+y` awaiting normal use.
- [04: Documentation corrections](issues/04-documentation.md) — claimed; done, minus the "shipped" lines the VM check would earn.
- [05: Yazi clipboard and shell](issues/05-clipboard-and-shell.md) — claimed; implemented and verified by pressing the keys.

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
- Ticket 05 arrived after the fact, from the operator: "copy" in a file manager
  is three operations, and Yazi's `;` and `:` are command-input boxes rather
  than a shell. It separates them across `y`, `<C-y>`/`<A-Y>` and `!`, and
  amends the spec's fourth behavior baseline, which named `Alt+y`.
- Kitty, Hyprland, Wofi, dunst, tmuxinator, Obsidian, `.zshrc2`, and the
  `backups/` snapshots were reviewed and deliberately dropped, not deferred.

## What the host settled, and what it could not

All three programs build, `nix flake check` passes, and the generated
`home-manager-files` carries each link this slice promises. Both halves of the
`Ctrl+h/j/k/l` feature are in place, and the two bindings this slice was asked
to repair are repaired: `prefix + Ctrl+d` saves and detaches, and `prefix + r`
reloads an edit made in the repository — which turned out to be broken for the
same class of reason, tmux never expanding `~` in `source-file`, on the legacy
host as well as here.

Neovim went further than the build: in a throwaway `XDG_*` sandbox running the
built editor against a copy of `configs/nvim/`, lazy installed every pinned
plugin, mason installed an npm package and a prebuilt server against the
Nix-provided Node, `prettierd` runs, a `.ts` file attaches `ts_ls` with
treesitter highlighting, and `:checkhealth` reports no dependency this
configuration actually uses as missing.

The remaining checks need the staging VM, and the `rsync` that puts the tree
there was refused by the implementing session's permission layer as a
shared-resource change. Waiting on that: a clean `bootstrap.sh install`, `:Lazy`
read in a real terminal, continuum's save hook (which refuses to install while
any other tmux server runs on the machine, so it cannot be seen on the
operator's host), `Alt+y` in a running Yazi, and `snap list yazi`.
