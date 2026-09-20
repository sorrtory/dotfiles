# 08 — Obsidian

Type: task
Status: resolved
Blocked by: 01

## What to build

Obsidian's theme is generated to a fixed path. A vault linked to it once
follows every switch after an Obsidian restart.

- A generated theme, based on today's Autumn Glass theme, at a fixed path.
- The README step: link the theme into each vault once and select it, and why
  vaults stay manual.
- In the hint, Obsidian is "restart to apply", and its check reports vaults
  activation knows about (the cloned Knowledge-Database) that lack the link.
  Locked or unknown vaults are left to the README.

## Acceptance

- [x] Autumn-glass renders a theme equivalent to today's Autumn Glass file.
- [x] A linked vault shows the new theme after a switch and restart, without
      re-linking.
- [x] The hint names Knowledge-Database when its link is missing and stays
      quiet once it exists.

## Comments

## Answer

Built in `modules/theme/obsidian-theme.nix`, read by
`modules/programs/obsidian.nix`; `tests/theme_obsidian_test.sh` covers the
three acceptance lines, comparing against the hand-made file as git still
has it.

- The theme is `~/.local/share/dotfiles/theme/obsidian/`, two `home.file`
  entries Home Manager repoints each generation, named "Dotfiles" in its
  manifest because Obsidian looks for `themes/<manifest name>/theme.css`.
  `configs/obsidian/` is gone; **the existing vault link points at it and has
  to be remade once**, which is what the hint now says.
- Of the 82 variables the hand-made theme set, 26 come out identical and 53
  more land within 10 of it per channel. The rest are the roles the palette
  actually has: `code-string` is the palette's success rather than the sage
  green that file used, so a string is one color across Sublime, VS Code,
  Neovim and Obsidian.
- Obsidian's chrome sits *above* the note rather than below it — ribbon, tabs
  and status bar are lighter than the page — which is the one app that reads
  the roles that way, and is how the hand-made theme was drawn. It is a mix
  of base and surface, not mantle.
- `mix`, `rgba` and `hsl` all live in `modules/theme/color.nix` now. Obsidian
  needs the last one: it derives its own ramp from an accent given as three
  HSL numbers, and `hsl "#c86138"` reproduces the file's `17, 57%, 50%`
  exactly.
- The check reports any `dotfiles.repositories` path that has a `.obsidian`
  directory but no link, resolved against `$HOME` at run time rather than the
  evaluated home directory, so it is testable and correct in the session that
  prints it. Locked or unknown vaults are the README's business, as the ticket
  said.
- Transparency does not reach Obsidian, for the reason the hand-made theme
  already recorded: Chromium redraws a see-through window with glitches on
  GNOME Wayland while it moves.
