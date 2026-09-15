# Spec: tmux configuration tweak

Status: needs-triage

## Why

`configs/tmux/tmux.conf` arrived from the legacy repository verbatim apart
from its plugin section. Reviewing it against the tmux 3.6 this repository
pins turns up one real defect, two plugins that are mostly inert, and a
layer of bindings and options that restate defaults — two of which quietly
replace a better default with a worse one.

## Proposal

### 1. Copy-mode copies nothing on X11

The `@clipboard-copy` chain picks the first tool that *exists*:
`wl-copy`, then `xclip`, then `xsel`. Nix installs `wl-clipboard` on every
machine, so an X11 session always reaches `wl-copy`, which exits 1 without a
Wayland server, and `xclip` is never tried. The staging VM is exactly that
session.

Replace the chain with tmux's own `copy-command` server option, choosing by
the display actually present:

```tmux
set -s copy-command 'if [ -n "$WAYLAND_DISPLAY" ]; then wl-copy; else xclip -selection clipboard -in; fi'
set -ga update-environment WAYLAND_DISPLAY
bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel
```

The default `Enter` and `MouseDragEnd1Pane` bindings already pipe to
`copy-command` with no argument, so their rebinds and `@clipboard-copy` go.
`update-environment` is meant to stop a long-lived server from carrying a
stale `WAYLAND_DISPLAY`; that it reaches `copy-command` jobs is unverified.
`xsel` stays undeclared, as it is today.

### 2. Retire continuum

Restoring is already manual (`@continuum-restore 'off'`), so continuum's only
remaining effect is a periodic save hidden inside `status-right`. Saving is
already explicit — `prefix + Ctrl+s`, and `prefix + Ctrl+d` to save and
detach — and restoring stays `prefix + Ctrl+r`. Resurrect stays.

### 3. Retire tmux-sensible, inlining what it still does

Against this file and tmux 3.6, most of sensible is a no-op: it only changes
`escape-time` from 500 (3.6's default is already 10), and `history-limit`,
`status-interval` and `default-terminal` are set here. What it still
contributes:

- `focus-events on` — keep; Neovim needs it to notice files changed outside.
- `display-time 4000` and `aggressive-resize on` — keep.
- `prefix + a` last-window, `prefix + C-n`/`C-p` window cycling — keep only if
  used.
- `status-keys emacs` — overrides the vi status keys tmux would otherwise pick
  from `EDITOR=nvim`. Probably not a choice anyone made.

With both retired, resurrect is the only plugin.

### 4. Remove restated defaults, and restore two better ones

Identical to the 3.6 default: `d`, `q`, `w`, `[`, `x`, copy-mode `V` and
`C-v`, `xterm-keys on`, `escape-time 10`, and the eight `unbind-key` lines
before the arrow bindings (`bind` already replaces).

Worse than the default they replace:

- `bind s choose-tree -s` drops the default `-Z` zoom.
- `bind ] paste-buffer` drops the default `-p`, bracketed paste, so pasting
  several lines into a shell can run them.

### 5. Small modernisations

- `#(whoami)` in `status-right` forks a shell every interval; `#{user}` is the
  same value without one.
- `H/J/K/L` resize is not repeatable while `Alt+Arrow` is; add `-r`.
- `terminal-overrides ',*:Tc'` → `terminal-features ',*:RGB'`, and
  `split-window -p 35` → `-l 35%`. Both old forms still parse in 3.6.

The explanatory comments are the operator's cheat sheet and stay, except
where the line they explain is removed.

## Open questions

Settled by grilling, in ticket 01:

- Retire tmux-sensible, or keep it for the few things it still sets?
- Which of sensible's window keys (`a`, `C-n`, `C-p`) survive, if any?
- `n` opens a window while `p` still means previous-window. Keep the
  asymmetry, restore `n` as next-window, or move new-window elsewhere?
- `status-keys`: vi (tmux's pick under `EDITOR=nvim`) or emacs (sensible's)?
- Should `escape-time 10` stay anyway, in case the file is carried to a remote
  server with an older tmux, as the status-bar comment anticipates?

## Scope

In scope: `configs/tmux/tmux.conf`, `modules/programs/tmux.nix`, and the
documentation rows these change — `docs/SOFTWARE.md` tmux plugins row,
`docs/DECISIONS.md` plugin-ownership and copy-chain paragraphs,
and `docs/MIGRATION.md` §11 and §12.

Out of scope: moving tmux onto `programs.tmux`, Neovim's side of the
navigation feature, and the Yazi clipboard plugin, which already chooses by
session type.

## Definition of done

- `nix flake check` and the activation package build succeed.
- On a private tmux server running the edited file: no errors in
  `show-messages`, and each changed binding does its job when pressed.
- On the staging VM's X11 session, copy-mode `y` puts text on the clipboard.
