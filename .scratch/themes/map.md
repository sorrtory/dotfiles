# Switchable color themes

One variable picks the theme and another picks transparency; every themed
app follows, generated from a single palette with per-app overrides. See
[spec.md](spec.md).

## Tickets

- [01: Theme core, proven in WezTerm](issues/01-theme-core.md) — resolved; see its Answer for the app-facing API (`forApp`, `apps`, `liveFiles`).
- [02: GNOME via a generated Rewaita palette](issues/02-gnome.md) — resolved; Rewaita reads a generated palette per theme.
- [03: Neovim](issues/03-neovim.md) — resolved; plugin per theme, generated colorscheme otherwise.
- [04: Sublime Text](issues/04-sublime-text.md) — resolved; generated scheme named "Dotfiles".
- [05: VS Code](issues/05-vscode.md) — resolved; a local extension contributes one theme called "Dotfiles", built from the native extension a palette names.
- [06: Spotify](issues/06-spotify.md) — resolved; the Spicetify scheme is generated, every slot derived from the roles.
- [07: Telegram](issues/07-telegram.md) — resolved; every key is generated from a table fitted once to the hand-made theme (323 keys have no fallback, so roots alone were not an option), packed at activation with the theme's wallpaper; the host check after the one-time Choose from file is the operator's.
- [08: Obsidian](issues/08-obsidian.md) — resolved; generated to a fixed path named "Dotfiles"; the existing vault link must be remade once.
- [09: Canonical docs and cleanup](issues/09-docs-and-cleanup.md) — claimed; canonical docs updated, pending normal-use checks and completion cleanup.
- [10: Instant Telegram apply](issues/10-instant-telegram-apply.md) — needs-info; blocked by 07 and upstream AyuGram.
- [11: Vesktop](issues/11-vesktop.md) — resolved; both numberings of the families Discord derives its tokens from are generated, live through Vencord's themes directory, and the window is faded by Blur my Shell rather than drawn translucent.
- [12: Zsh](issues/12-zsh.md) — resolved; prompt, highlighting, suggestion and completion generated from the roles into one live file the shell re-sources from `precmd`, loaded as `$ZSH_THEME=dotfiles` through a shim theme because a store symlink cannot carry a changing mtime. Checked end to end on the staging VM: activation writes both files, the notice lists Zsh as live, and an open shell recolors in place.
- [13: Terminus](issues/13-terminus.md) — claimed; generated from all palettes with Gruvbox's soft base and text preserved, pending visual host verification.
- [14: Markdown in the generated colorscheme](issues/14-markdown-legibility.md) — resolved; heading levels ramp red to green through `blend`, links separate by underline rather than by a hue the palette does not have, and the check parses a real buffer.

Tickets 02–08 and 11–14 are independent of each other once 01 lands.

## Context

- Decisions come from a grilling session on 2026-09-18; the spec records all
  of them. The Telegram flow rests on a source reading of tdesktop and
  AyuGram, summarized in the spec.
- The pinned Rewaita 1.1.7 ships `One Dark ⚛️` (`--theme=one-dark`) and reads
  user palettes from `~/.local/share/rewaita/dark/`.
- Nixpkgs in the pin carries `vscode-extensions.jdinhlife.gruvbox` (1.29.1) and
  `zhuangtongfa.material-theme` (3.19.0).
- `docs/DECISIONS.md` records the repository palette as the source of truth;
  Rewaita consumes its colors for GNOME and Firefox.
