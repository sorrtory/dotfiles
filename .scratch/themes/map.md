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
- [06: Spotify](issues/06-spotify.md) — resolved; the Spicetify scheme is generated, with autumn-glass pinning the four shades no role names.
- [07: Telegram](issues/07-telegram.md) — needs-info; blocked by 01 and by a decision recorded in its Comments: 544 hand-tuned keys, so fallback roots or a full mapping table.
- [08: Obsidian](issues/08-obsidian.md) — resolved; generated to a fixed path named "Dotfiles"; the existing vault link must be remade once.
- [09: Canonical docs and cleanup](issues/09-docs-and-cleanup.md) — ready-for-agent; blocked by 02–08.
- [10: Instant Telegram apply](issues/10-instant-telegram-apply.md) — needs-info; blocked by 07 and upstream AyuGram.

Tickets 02–08 are independent of each other once 01 lands.

## Context

- Decisions come from a grilling session on 2026-09-18; the spec records all
  of them. The Telegram flow rests on a source reading of tdesktop and
  AyuGram, summarized in the spec.
- The pinned Rewaita 1.1.7 ships `One Dark ⚛️` (`--theme=one-dark`) and reads
  user palettes from `~/.local/share/rewaita/dark/`.
- Nixpkgs in the pin carries `vscode-extensions.jdinhlife.gruvbox` (1.29.1) and
  `zhuangtongfa.material-theme` (3.19.0).
- `docs/DECISIONS.md` currently makes Rewaita's Gruvbox preset the baseline;
  ticket 02 changes that and ticket 09 records it.
