# 07 — Telegram (AyuGram)

Type: task
Status: resolved
Blocked by: 01

## What to build

AyuGram's theme is generated from the palette to a fixed path. After a
one-time "Choose from file", every later switch applies at the next AyuGram
start.

- A template covering every color key in today's Autumn Glass theme, each
  mapped to a role or override, with alphas from the transparency table.
- Each theme's chat background, falling back when a theme has none.
- The generated theme at a fixed path that Home Manager repoints on each
  generation.
- The README step: choose that file once in Settings → Chat settings, and why
  it cannot be automated (encrypted tdata, see the spec's Telegram findings).
- Telegram registers as "restart to apply" with its one-time setup in the hint.

## Acceptance

- [x] Autumn-glass renders a theme equivalent to today's Autumn Glass file
      (now: its colors, handed to the table, repaint that file).
- [ ] After the one-time load, switching theme and restarting AyuGram shows the
      new theme on the host.
- [x] Each theme's file stays under Telegram's 5 MB theme limit.

## Comments

### Survey before starting, 2026-09-20

Left open deliberately: this is larger than 05, 06 and 08 together, and the
shape of the answer is a decision, not a detail.

`configs/ayugram/autumn-glass/colors.tdesktop-theme` sets **544 keys**: 438
literal colors and 106 references to another key. Those 438 literals are
**319 distinct hexes**, most used once, many carrying their own alpha. It is
not a palette expressed in Telegram's vocabulary — it is a hand-tuned
painting, so a key-by-key mapping onto thirteen roles is not a transcription
but a redesign of every surface, and a generator built from those 319 values
would be guesswork dressed as a rule.

Two routes, and the ticket should pick one before any code:

1. **Fallback roots.** tdesktop declares a fallback for every palette color,
   so a theme can set only the `window*`, `button*` and `msg*` roots and let
   the client resolve the rest. That is how a theme is normally hand-written,
   it is maybe forty keys, and it is honestly derivable from the roles. It
   will not reproduce today's file: everything the hand-tuning did between
   the roots and the leaves is lost.
2. **Full listing.** Keep all 544 keys, each mapped to a role, a mix or a
   palette override — the ticket as written. Reproduces autumn-glass, and
   costs a mapping table the size of the file.

Route 1 with a per-theme override block for the surfaces that visibly matter
is probably the right trade, but the acceptance line "renders a theme
equivalent to today's Autumn Glass file" has to be relaxed first, by the
operator, because route 1 cannot meet it.

Also note the acceptance cannot be finished here: "switching theme and
restarting AyuGram shows the new theme **on the host**" needs a real Telegram
login and the VPN namespace, so the last check is the operator's either way.
The 5 MB limit is not a risk — today's packed theme is 806 KB, almost all of
it `background.png`.

## Answer

Resolved 2026-09-22, and neither route in the survey: its premise was wrong.
In AyuGram 7.0.9's palette (lib_ui `ec0c178`, `ui/colors.palette`) only 263 of
586 keys fall back to another; the other 323 are literal light-theme colors,
so a forty-root theme would leave most of the window white.

What made the full listing cheap instead: every one of the hand-made file's
438 literals is a mix of two of Autumn Glass's roles (or white or black) to
within a few units — median 4/255, 88% within 8. So
`modules/theme/telegram-keys.nix` was generated once from that file: each key
is `color`, `mix` or `ref` over role names, with the author's alpha. The eight
per-user colors (`historyPeer1..8`) take the palette's ANSI colors instead,
and thirteen keys the hand-made file never set (bot keyboard, search
highlight, rank badges) were mapped by hand. `modules/theme/telegram-theme.nix`
renders it, resolving references so line order cannot matter; with
transparency off, alphas of 0x80 and up go solid.

AyuGram's module packs it during activation with the theme's wallpaper from
`~/Pictures/wallpapers/<theme>.jpg` — the picture GNOME shows, outside the
repository, re-encoded because a wallpaper alone can exceed Telegram's 5 MB
limit — or one solid color when there is none, to
`~/.local/share/dotfiles/theme/telegram/Dotfiles.tdesktop-theme`. Always a
still `background.*`, never `tiled.*`, which Telegram repeats as a pattern. Telegram registers as restart-to-apply with the Choose from
file step. `tests/theme_telegram_test.sh` covers the rest, including that the
old palette still repaints the old file.

Left for the operator: the host check (choose the file once, switch, restart
AyuGram), which needs the real login. `configs/ayugram/` is now unused and is
ticket 09's to remove.
