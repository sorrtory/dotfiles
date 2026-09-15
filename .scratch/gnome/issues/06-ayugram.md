# 06 — AyuGram as the Telegram client

Type: task
Status: resolved

## Goal

Install AyuGram from Nixpkgs as a global desktop application, so the
`telegram` launcher (`<Super>m`, ticket 03) has something to open on the new
PC.

## Facts

- Pinned Nixpkgs (`nixos-26.05`) has `ayugram-desktop` 6.7.8. It is free
  software, and `meta.mainProgram` is `AyuGram`. `telegram-desktop` is 6.8.1.
- The current PC runs the official Telegram, installed by hand under
  `~/.local/opt/Telegram` and linked from `~/.local/bin/telegram-desktop`,
  with its data in `~/.local/share/TelegramDesktop`. `docs/SOFTWARE.md` has
  no Telegram row.
- AyuGram is a Qt app drawing through OpenGL. Coming from Nix, it is one more
  program outside MPV's driver wrapper. See the README's "GPU-accelerated
  programs".

## Work

1. Add `ayugram-desktop` to `modules/packages.nix`.
2. Add an AyuGram row to `docs/SOFTWARE.md`: a Home Manager global desktop
   application, with login and session state machine-local.
3. Set the `telegram` launcher command in ticket 03 to `AyuGram`.

## Decided

Operator, 2026-09-15: AyuGram replaces the official Telegram, and the
hand-installed `~/.local/opt/Telegram` flow is not carried over. The operator
may fall back to the native Telegram later. Keep that switch cheap: the
launcher stays named `telegram`, so falling back changes only its command and
the package, not the binding.

## Acceptance

- `nix flake check` and the activation package build succeed.
- On a GNOME VM or the new PC, `<Super>m` opens AyuGram, and it logs in.

## Answer

Landed in `modules/packages.nix` (`ayugram-desktop`), with an AyuGram row in
`docs/SOFTWARE.md`. The `telegram` launcher already ran `AyuGram` since 03.

Verified 2026-09-15:

- **Host:** `nix flake check` passes, and the activation package builds. The
  generation has `bin/AyuGram` and `com.ayugram.desktop.desktop`. The
  package (6.7.8, GPL-3.0) is in the binary cache; its closure is about 2 GiB.
- **Ubuntu GNOME VM, after re-login:** `<Super>m` starts AyuGram, and its window
  draws the "Scan From Mobile Telegram" login screen.
  - Qt logs `QRhiGles2: Failed to create context` and
    `QOpenGLWidget is not supported on this platform`. The VM has no GPU and
    Nix programs cannot use the distro's drivers (see DECISIONS.md's GPU
    section), yet the UI still renders.
  - On real hardware, whether AyuGram's media and animations need
    acceleration belongs to the README's "GPU-accelerated programs"
    checklist.

Not verified: logging in, which needs the operator's phone, and normal use on
the new PC.

## Comments
