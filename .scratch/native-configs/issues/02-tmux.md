# 02 — tmux

Status: claimed

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

## Comments

Implemented on the host, with one deliberate deviation from step 2 and one
extra fix.

The deviation: `programs.tmux.enable` cannot coexist with step 3. That option
always defines `xdg.configFile."tmux/tmux.conf".text`, so pointing the same
path at a `mkOutOfStoreSymlink` is a conflicting definition, and forcing ours
through would leave `programs.tmux.plugins` generating plugin loads into a file
nobody reads. `modules/programs/tmux.nix` therefore declares `pkgs.tmux` with
`home.packages` and links the three plugins itself, under their upstream names
(`tmux-sensible`, `tmux-resurrect`, `tmux-continuum`), which is the layout TPM
produced. The module still owns the package it configures, so the
`docs/DECISIONS.md` rule holds, and `tmux` is not in `modules/packages.nix`.

That layout is also the answer to step 5: the `prefix + Ctrl+d` binding names
`~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh`, and the path now
resolves to resurrect's own script rather than to nothing, so the binding is
repaired without reproducing the wrong path or hard-coding a store path into a
native file.

The extra fix: `prefix + r` was broken in exactly the same silent way, and the
ticket did not know it. `source-file ~/.config/tmux/tmux.conf` fails with
`No such file or directory: ~/.config/tmux/tmux.conf`, because tmux resolves a
non-absolute `source-file` argument against the client's working directory and
never expands the tilde. Confirmed against both tmux 3.6a from this closure and
the host's own tmux 3.6, so it is pre-existing rather than a regression from
this slice. The binding now goes through `run-shell`, the same idiom the
`Ctrl+d` binding beside it already used, where the shell expands the tilde.

Everything else in `tmux.conf` is verbatim; `git diff` against the legacy file
shows only the plugin section, the two binding changes, and their comments.
`grep -c tpm configs/tmux/tmux.conf` returns 0.

Verified on the host without activating, by starting a tmux server on a private
socket with `HOME` and `XDG_STATE_HOME` in a throwaway sandbox, the repository
file symlinked in as activation would link it, and the plugin directories
copied from the built `home-manager-files`:

- all three plugins load with no error in `show-messages`; `prefix` is `C-a`,
  `C-b` is unbound, sensible's `prefix a` and resurrect's `prefix C-s` and
  `prefix C-r` bindings are present, and `@resurrect-dir`,
  `@continuum-save-interval` and `@continuum-restore` hold their intended
  values.
- `prefix + Ctrl+d`, run as the command tmux itself stored in the key table,
  with a real client attached through a pty: resurrect wrote
  `$XDG_STATE_HOME/tmux/resurrect/tmux_resurrect_*.txt` and its `last`
  symlink, the "tmux environment saved; detaching" message was displayed, the
  client detached, and the session survived.
- `prefix + r`, also run from the key table: an edit appended to
  `configs/tmux/tmux.conf` in the repository appeared in the server's options
  after the reload, and the message was displayed. The file was restored byte
  for byte afterwards.
- the `is_vim` condition answers correctly per pane — "vim" for a pane running
  Neovim, "not vim" for a shell pane — so `Ctrl+h` sends the key into Neovim in
  the first case and moves tmux panes in the second. This is the tmux half of
  the shared feature; ticket 01's `vim-tmux-navigator` is installed.

Two things the host cannot settle. Continuum's periodic save hook refuses to
install itself when another tmux server is already running on the machine — by
design, so two servers cannot overwrite each other's saved state — and the
operator's own tmux server was running throughout, so `status-right` was left
alone. A machine with no other server is the place to see that, which means the
VM. And `Ctrl+h` pressed by a human, rather than its condition evaluated, is a
normal-use check.

The VM could not be synced from this session: `rsync` to the guest was refused
by this session's permission layer as a shared-resource change.

## Comments — Operator activation on staging, 2026-09-15

The operator activated the Lubuntu VM and reports tmux working. No defect was
raised. Reviewing `tmux.conf` itself, including retiring continuum, belongs to
the `tmux-config-tweak` effort rather than this ticket, so continuum's save
hook is no longer a check this slice owes.
