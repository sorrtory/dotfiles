# GNOME preferences

Move intentional GNOME dconf preferences out of the legacy
`install.sh gnome` / `install.conf` path and into
`modules/desktops/gnome.nix`. The target is a fresh Ubuntu install on a new
PC that feels like the current one. See [spec.md](spec.md).

## Tickets

- [01: Grill the GNOME baseline](issues/01-grill-the-baseline.md) — resolved.
- [02: Keyboard layouts, Alt+Shift and Caps Lock](issues/02-keyboard.md) — ready-for-agent.
- [03: Launchers and keybindings](issues/03-keybindings.md) — ready-for-agent.
- [04: Mutter, dock and appearance](issues/04-mutter-dock-appearance.md) — needs-triage.
- [05: Extensions and GNOME tools](issues/05-extensions-and-tools.md) — ready-for-agent.
- [06: AyuGram as the Telegram client](issues/06-ayugram.md) — ready-for-agent.

Launchers (03) and extensions (05) are the operator's priority. None of the
three ready tickets blocks another. Whichever lands first creates
`modules/desktops/gnome.nix` and the `home.nix` import, and the others extend
it.

## Context

- Every "host" value in the spec was read with `dconf dump` and `gsettings`
  on 2026-09-15, not taken from `install.conf`. The two disagree in several
  places, and the Caps Lock option exists only on the host.
- The current PC is evidence only. Nothing is switched on it. See
  [01](issues/01-grill-the-baseline.md).
- Home Manager behavior comes from the pinned sources (`65258d5`): `dconf.nix`,
  `programs/gnome-shell.nix`, `targets/generic-linux.nix`,
  `xdg-system-dirs.nix` and `systemd.nix`. None of it is from memory.
- `targets.genericLinux` also enables its GPU module by default, which
  conflicts with the MPV GPU decision. That decision's premise ("MPV is the
  only program here that needs a GPU") predates Code, Obsidian and Spotify
  coming from Nix, so it needs revisiting outside this effort.
- Running this effort alongside `vpn-command`:
  - Its files don't overlap, apart from one import line in `home.nix`.
  - The staging VM is shared, and `rsync --delete` mirrors a whole tree.
    Two efforts syncing different working trees would overwrite each other's
    guest copy, so staging must be taken in turns.
  - The current Lubuntu VM has no GNOME and has been reset. The operator will
    add an Ubuntu GNOME VM.
