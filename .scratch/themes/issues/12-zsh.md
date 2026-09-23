# 12 — Zsh

Type: task
Status: resolved
Blocked by: 01

## What to build

The shell follows the palette like every other themed app. Today it does not:
`zsh-autosuggestions` is pinned to `fg=244`, `zsh-syntax-highlighting` runs on
its own defaults, and the prompt is the oh-my-zsh theme `flazz`, written in
the terminal's eight named colors.

- The prompt, the highlighting styles, the suggestion's ghost text and the
  completion listing generated from the roles.
- The colors in a file of their own rather than in `.zshrc`, because a shell
  reads `.zshrc` once: a switch has to reach the shells already open, not only
  the next one.
- A decision on the oh-my-zsh theme, which cannot be kept as it is and also
  follow the palette.

## Acceptance

- [x] Each palette renders a prompt and a style table in that palette's roles,
      and zsh itself draws them.
- [x] A switch recolors a shell that is already open, at its next prompt.
- [x] `zsh-syntax-highlighting`, which loads after the colors, leaves every
      generated style alone.
- [x] An override in `home.nix` reaches the shell like any other app's.
- [x] A shell that starts before the first activation still reaches a prompt.
- [x] The dirty marker is told apart from the branch in every palette.
- [x] The colors load as `$ZSH_THEME`, the way any oh-my-zsh theme does, and
      a switch still recolors an open shell loaded that way.

## Answer

`modules/theme/zsh-colors.nix` writes one zsh file out of the roles, and
`modules/programs/zsh.nix` registers it as a live file at
`~/.local/share/dotfiles/theme/zsh.zsh` with `apply = "live"`.

**Named colors were not an option.** WezTerm already takes its ANSI colors
from this palette, so a prompt written in `$fg[green]` follows the theme in
WezTerm and nowhere else — in any other terminal it follows that terminal.
The generated file uses `%F{#rrggbb}` and `fg=#rrggbb`, which zsh 5.7 and
later understand, so the colors are the palette's wherever the shell runs.
That rules out keeping one of the *bundled* oh-my-zsh themes: every one of
them writes its own `PROMPT` out of those eight names. `oh-my-zsh.theme` is
`dotfiles`, a theme of our own, keeping flazz's layout — host, path, branch,
caret — in roles.

**The theme oh-my-zsh loads is a three-line shim.** `oh-my-zsh.custom` points
at `~/.local/share/dotfiles/zsh-custom`, and `themes/dotfiles.zsh-theme`
there sources the live file. The colors cannot live in the theme itself:
Home Manager writes it with `xdg.dataFile`, which is a symlink into the Nix
store, and every file in the store carries mtime 1. The reload hook watches
mtime, so a theme holding the colors directly would look right in a new shell
and never once recolor an open one — failing silently, which is the worst
shape this could fail in. The shim is static, so it symlinks safely.

The shim guards with `if [[ -r ... ]]` rather than `&&`, so it returns 0 when
the colors are not written yet. A theme is the last thing `.zshrc` runs
before the first prompt, and `RPS1` draws a non-zero status there as a failed
command.

`.zshrc` then reads the same file a second time when it installs the hook.
That is deliberate: the read is what records the mtime the hook compares
against, so skipping it would only move the second read to the first prompt.
The file does nothing but assign, so the cost is microseconds, and it is also
the path that still reaches a prompt in a shell where oh-my-zsh never ran.

**Live apply is the shell watching its own file, not activation signalling
it.** `.zshrc` reaches the file at startup — through the theme, then again
when it installs the hook — and re-sources it from a `precmd` hook when its
mtime changed, which costs one `zstat` per prompt and no state
beyond the mtime it already read. The hook goes in front of the hooks
oh-my-zsh registered, so the colors are in place before oh-my-zsh asks git for
the branch it is about to draw.

**Ordering inside `.zshrc` is what makes the styles hold.** Home Manager emits
oh-my-zsh at init order 800, `initContent` at 1000 and
`zsh-syntax-highlighting` at 1200. The colors land twice inside that window —
at 800 as the theme, at 1000 to seed the hook — and both are before the
highlighter loads, which is what matters here. The highlighter
fills in each style with `:=`, so it leaves a style already set alone. The
generated file declares `typeset -gA ZSH_HIGHLIGHT_STYLES` itself, because a
subscript assignment to a name that does not exist yet would make an ordinary
array rather than an associative one.

**The dirty marker is `error`, not `warning`.** Rendering the finished prompt
through oh-my-zsh showed it in the color of the brackets around it under
autumn-leaves, whose palette makes `warning` and `accent2` the same copper.
`error` is the one role no palette can collapse into the second accent, and
red for a dirty tree is the convention anyway.

`tests/theme_zsh_test.sh` covers the acceptance lines, and drives them through
zsh rather than through the file: it renders `$PROMPT` with `print -rP` and
matches the true-color SGR zsh emits, so a zsh that could not draw a hex would
fail rather than pass on a string match. It also loads the real highlighter
over the generated styles, and runs the reload hook as `.zshrc` ships it
against a file it changes underneath.

## Comments

**2026-09-23 — checked on the staging VM.** A full `staging` activation could
not be run there: the guest is 11.5 GiB short of the closure, which is the
18 GiB disk `docs/STAGING.md` already warned about rather than anything to do
with this change. The numbers and the two traps behind them are recorded in
that document.

The shell itself was checked on the guest instead, with the real generated
`.zshrc` and the theme files for two palettes copied in. One interactive zsh,
started once (PID 10090), with the theme file switched underneath it:

| | autumn-leaves | gruvbox |
|---|---|---|
| host / separator / path / caret | `#dcc4ab` `#9c7f6c` `#c2ad4b` `#d2703f` | `#d5c4a1` `#a89984` `#b8bb26` `#fe8019` |
| `comment` style | `fg=#9c7f6c` | `fg=#a89984` |
| `path` style | `fg=#e9a15e,underline` | `fg=#83a598,underline` |
| suggestion | `fg=#8a6f60` | `fg=#928374` |

Every one of them changed at the next prompt in that same process, which is
the claim `apply = "live"` makes. The hook order held as intended:
`_direnv_hook _dotfiles_theme_load _zsh_autosuggest_start _omz_async_request
omz_termsupport_precmd _zsh_highlight_main__precmd_hook`.

The branch segment needed a repository of its own, because the mirrored tree
has no `.git/` by design. In one: `‹main›` in the second accent, and the dirty
marker in `error` — `#fb4934` against `#83a598` under gruvbox, `#e8604c`
against `#e9a15e` under autumn-leaves. That is the palette the marker was
invisible in before the role changed, so the fix is confirmed on a real
machine and not only in the test.

Still unchecked on a guest at the time of this note: the activation step that
writes the live file and prints Zsh under "Updated live". The note dated later
the same day closes it.

**2026-09-23 — packaged as an oh-my-zsh theme.** The colors were a loose file
that `.zshrc` sourced, with `oh-my-zsh.theme` unset. They are now
`$ZSH_THEME=dotfiles`, loaded through oh-my-zsh's own theme mechanism, for
consistency with how every other oh-my-zsh setting here is expressed. The
mechanism is the shim described above; nothing about the generated colors
changed.

Checked by driving the real `oh-my-zsh.sh` with `ZSH_CUSTOM` and
`ZSH_THEME=dotfiles` against the generated shim: oh-my-zsh found the theme
(no `theme 'dotfiles' not found`), the prompt rendered in autumn-leaves —
`#dcc4ab` `#9c7f6c` `#c2ad4b` `#d2703f` — and `ZSH_HIGHLIGHT_STYLES[comment]`
came out `fg=#9c7f6c`. Swapping the live file underneath that same shell and
running its `precmd_functions` moved all four to gruvbox — `#d5c4a1`
`#a89984` `#b8bb26` `#fe8019` — so the theme packaging does not cost the live
apply, which was the thing at risk.

**2026-09-23 — activation run end to end on the staging VM.** The guest has a
30 GiB disk now, so the gap both notes above left open is closed. From the
mirrored tree, `staging` built four derivations and downloaded nothing.

The shim landed as
`~/.local/share/dotfiles/zsh-custom/themes/dotfiles.zsh-theme`, a symlink into
the store whose target reports `mtime=1`. That is the reason the colors are
not in it, measured rather than reasoned: had they been, the reload hook would
have compared 1 against 1 forever. The live file beside it kept a real
timestamp and was rewritten in place on each switch.

Switching autumn-leaves → gruvbox printed Zsh under **Updated live**, which is
the line this ticket had never actually seen. The shell opened before the
switch (PID 39343) recolored in that same process: `#d5c4a1` `#a89984`
`#b8bb26` `#fe8019`, suggestion `fg=#928374`, `comment` `fg=#a89984`. Hook
order held: `_direnv_hook _dotfiles_theme_load _zsh_autosuggest_start
_omz_async_request omz_termsupport_precmd _zsh_highlight_main__precmd_hook`.
Switching back printed Zsh under **Updated live** again and a new shell came
up in autumn-leaves.

A shell started after the switch reported `ZSH_THEME=dotfiles` and
`ZSH_CUSTOM=~/.local/share/dotfiles/zsh-custom`, with no
`[oh-my-zsh] theme 'dotfiles' not found` — so oh-my-zsh's own loader resolves
the generated theme.

With the live file moved aside, a fresh shell still started, printed nothing,
fell back to zsh's default `[%n@%m]%~%#`, and left `$?` at **0**. That is the
`if` rather than `&&` in the shim, confirmed on a real machine: `&&` would
have left a non-zero status for `RPS1` to draw as a failed command on the
first prompt of an unactivated machine.

**A sampling trap, for anyone checking this again.** `precmd` runs *after* the
command you just sent and before the next prompt, so reading `$PROMPT` in the
same command line that follows a switch shows the *old* colors. It looks
exactly like a failed reload. Send one more command and read it again.
