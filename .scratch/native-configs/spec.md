# Spec: Native program configurations

Status: ready-for-agent

## Why

`docs/MIGRATION.md` slices 10, 11, and 12 promote Neovim, tmux, and Yazi from
deferred candidates into the core milestone. They are one slice-shaped problem
wearing three names: each is a readable native configuration the operator
edits often, and each depends on plugin assets the legacy `manager.sh`
restored into `~/.local/share/configs-manager/` from pins in `manager.lock`.

Nothing in this repository provides any of them today. `modules/programs/
neovim.nix` exists but declares only `enable` and `defaultEditor`; the actual
configuration is 88K of Lua in the legacy repository. A fresh bootstrap
currently yields a bare Neovim, no tmux configuration, and no Yazi.

This spec answers the shared mechanism question once, so the three tickets do
not each re-litigate it.

## The shared mechanism

**Configuration stays native and live-editable.** Each program keeps its own
format in `configs/<program>/`, exposed through `mkOutOfStoreSymlink`. None of
it is translated into a Home Manager option model. All three reload their
configuration in place — `:source`, `prefix + r`, Yazi restart — and that is
worth more than expressing the same content as Nix.

**Plugin ownership is decided per program, not by rule.** The deciding
question is what the program's plugin manager costs on a fresh machine versus
what replacing it costs:

- tmux and Yazi: Nix owns the plugins. Their plugin sets are three and one
  entries respectively, all available packaged, and their managers each
  require a network fetch and a manual first-run step.
- Neovim: `lazy.nvim` and mason keep ownership. Sixteen plugin specs are
  already pinned by `lazy-lock.json`, and moving them into Nix would trade
  live editability and lazy-loading for reproducibility that an editor does
  not need badly enough to pay that price.

**Nix supplies what a retained manager assumes exists.** This is the real
obligation the Neovim decision creates, and ticket 01 is mostly about it.

## Scope

In scope: `modules/programs/{neovim,tmux,yazi}.nix`, their configurations
under `configs/`, tmux and Yazi plugins, Node.js as a global user tool, and
the documentation rows this changes.

Out of scope:

- The legacy `~/Documents/configs/` repository and `manager.sh`. The operator
  retires it by reinstalling the host. Nothing is removed from the current
  host by this slice.
- Kitty, Hyprland, Wofi, dunst, tmuxinator, Obsidian, `.zshrc2`, and the
  `backups/` snapshots. All reviewed and deliberately dropped.
- Translating any of the three configurations into Nix option models.

## Behavior baseline

1. Neovim starts with all 16 plugins and working LSP, formatting, and
   treesitter highlighting, without the operator hand-installing anything.
2. `Ctrl+h/j/k/l` moves between Neovim splits and tmux panes seamlessly, in
   both directions. This is one feature implemented in two files.
3. tmux sessions survive a reboot through resurrect/continuum.
4. Yazi's `Alt+y` copies file contents.

## Definition of done

- `nix flake check` and `nix build .#homeConfigurations.z.activationPackage`
  succeed on the host, and every `tests/*.sh` passes.
- On the staging VM, a normal `bootstrap.sh install` from a clean state
  produces all three programs working, with no path resolving under
  `~/.local/share/configs-manager/`.
- The four baseline behaviors above are confirmed by normal use, not only by
  the build succeeding.
