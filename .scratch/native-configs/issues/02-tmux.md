# 02 — tmux

Status: ready-for-agent

## Goal

Let Home Manager own tmux and its three plugins, retiring TPM, while keeping
`tmux.conf` readable and live-editable.

## Work

1. Copy `~/Documents/configs/tmux/tmux.conf` to `configs/tmux/tmux.conf`.
2. Create `modules/programs/tmux.nix` with `programs.tmux.enable = true` and
   `plugins = with pkgs.tmuxPlugins; [ sensible resurrect continuum ]`.
3. Expose the config through `mkOutOfStoreSymlink` at
   `xdg.configFile."tmux/tmux.conf"`.
4. Remove the TPM machinery from `configs/tmux/tmux.conf`: the
   `TMUX_PLUGIN_MANAGER_PATH` `run-shell` line, the four `set -g @plugin`
   lines, and the trailing `run-shell '#{E:TMUX_PLUGIN_MANAGER_PATH}tpm/tpm'`
   initializer.
5. Fix the `Ctrl+a Ctrl+d` binding.
6. Import the module from `home.nix`.

## Constraints

- **`Ctrl+a Ctrl+d` is broken today, before this slice touches anything.** It
  runs `~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh`, but
  `TMUX_PLUGIN_MANAGER_PATH` points at
  `$XDG_DATA_HOME/configs-manager/tmux/plugins/`, and
  `~/.config/tmux/plugins/` does not exist. Repoint it at the packaged
  resurrect script rather than reproducing the wrong path.
- Keep `@resurrect-dir` at `$XDG_STATE_HOME/tmux/resurrect` and
  `@continuum-restore 'off'`. Saved sessions are machine-local mutable state,
  not repository material.
- Everything else in `tmux.conf` is behavior baseline and moves verbatim: the
  `C-a` prefix, the split and pane-jump bindings, the `is_vim` integration,
  the copy-mode clipboard chain, and the status line.
- The `is_vim` bindings pair with `configs/nvim/lua/plugins/tmux.lua`. Both
  halves must be present for seamless navigation; ticket 01 supplies the other.
- `docs/DECISIONS.md` requires that a program module owns the package it
  configures. Do not also declare `tmux` in `modules/packages.nix`.

## Acceptance

- `nix build .#homeConfigurations.z.activationPackage` succeeds.
- On the staging VM after activation:
  - `~/.config/tmux/tmux.conf` resolves into `~/Documents/dotfiles`;
  - starting tmux requires no `prefix + I` and no network fetch;
  - `prefix + Ctrl+d` saves the environment and detaches, showing the
    confirmation message rather than failing silently;
  - `prefix + r` reloads after an edit to the file in the repository;
  - `Ctrl+h` from inside Neovim moves to the Neovim split, and from a shell
    pane moves to the tmux pane.
- `grep -c tpm configs/tmux/tmux.conf` returns 0.
