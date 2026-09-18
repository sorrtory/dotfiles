# 10 — Instant Telegram apply

Type: task
Status: needs-info
Blocked by: 07; AyuGram shipping tdesktop's `theme-apply` control command

## What to build

When AyuGram gains the control command Telegram Desktop added in 7.2.6,
activation can apply the generated theme instantly, instead of waiting for
the next start.

- Needs: an AyuGram release with the command, and the one-time in-app
  automation opt-in documented.
- The client must run in the VPN wrapper's network namespace, where AyuGram's
  socket lives.
- It must never start or restart AyuGram; with AyuGram not running, the hint's
  restart line stays.

## Acceptance

- [ ] With AyuGram running and automation enabled, a switch recolors it with no
      restart, and the hint moves Telegram to "live".

## Comments
