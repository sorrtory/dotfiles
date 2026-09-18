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
