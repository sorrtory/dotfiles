# 07 — Telegram (AyuGram)

Type: task
Status: ready-for-agent
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

- [ ] Autumn-glass renders a theme equivalent to today's Autumn Glass file.
- [ ] After the one-time load, switching theme and restarting AyuGram shows the
      new theme on the host.
- [ ] Each theme's file stays under Telegram's 5 MB theme limit.

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
