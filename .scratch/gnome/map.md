# GNOME preferences

Move intentional GNOME dconf preferences out of the legacy
`install.sh gnome` / `install.conf` path and into
`modules/desktops/gnome.nix`. The target is a fresh Ubuntu install on a new
PC that feels like the current one. See [spec.md](spec.md).

## Tickets

- [01: Grill the GNOME baseline](issues/01-grill-the-baseline.md) — resolved.
- [02: Keyboard layouts, Alt+Shift and Caps Lock](issues/02-keyboard.md) — resolved.
- [03: Launchers and keybindings](issues/03-keybindings.md) — resolved.
- [04: Mutter, dock and appearance](issues/04-mutter-dock-appearance.md) — resolved.
- [05: Extensions and GNOME tools](issues/05-extensions-and-tools.md) — resolved.
- [06: AyuGram as the Telegram client](issues/06-ayugram.md) — resolved.
- [07: Focus existing windows from application shortcuts](issues/07-run-or-raise.md) — implemented and tested in isolated GNOME 50.4; needs-info for remaining VM staging checks.

Launchers (03) and extensions (05) are the operator's priority. None of the
ready tickets blocks another. Ticket 05 created `modules/desktops/gnome.nix`,
its `home.nix` import and `targets.genericLinux`, and the others extend them.

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
- Resolved by [05](issues/05-extensions-and-tools.md):
  - Ubuntu enables its default extensions through the `ubuntu` session mode,
    not `enabled-extensions`, and `disabled-extensions` overrides that.
  - GNOME Shell 50 loads extensions symlinked from `~/.nix-profile/share`
    after a re-login.
  - The operator's machines span Ubuntu, Fedora and possibly NixOS, so GNOME
    tools come from Nixpkgs.
  - Check extensions with the session unlocked: the lock screen disables them.
- Resolved by [03](issues/03-keybindings.md):
  - Launchers use plain command names. The session `PATH` gets the profile's
    `bin` through `environment.d`.
  - Nix VS Code and Obsidian could not start on Ubuntu without an AppArmor
    `userns` allowance for their Electron. That is now fixed outside the
    tickets: `modules/apparmor.nix` generates `dotfiles-vscode` and
    `dotfiles-electron-43`, and both apps use the HTTP proxy rather than the
    VPN. See docs/VESKTOP-APPARMOR.md.
  - Test workspace moves with two windows.
  - Gradia comes from Nixpkgs, and `<Shift>F11` runs
    `gradia --screenshot=INTERACTIVE`. It is verified on the VM, and Flatpak is
    no longer needed.
  - Mutter's tiling keys on the current PC belong to Tiling Assistant, not
    the operator; see [04](issues/04-mutter-dock-appearance.md).
- Resolved by [02](issues/02-keyboard.md): the keyboard works on the VM. The
  Alt+Shift toggle and GNOME's switcher stay in step. Turning Caps Lock on
  with Shift+Caps Lock also sends Escape, a quirk the XKB keymap doesn't
  explain; the operator kept the option. Test keys through `cat > file` in a
  terminal and read the bytes back.
- Resolved by [04](issues/04-mutter-dock-appearance.md):
  - Read Ubuntu's effective defaults with `XDG_CURRENT_DESKTOP=ubuntu:GNOME`.
    Over plain `ssh`, `gsettings` shows the upstream schema values instead.
  - The dock and appearance are declared in full, so other distros match.
    Monitor keys and Tiling Assistant's Mutter keys are not declared.
- Resolved by [06](issues/06-ayugram.md): AyuGram installs from the binary
  cache and renders without a GPU on the VM. Logging in is left to the
  operator.
- When this effort ran alongside the selectable VPN implementation:
  - Its files don't overlap, apart from one import line in `home.nix`.
  - The staging VM is shared, and `rsync --delete` mirrors a whole tree.
    Two efforts syncing different working trees would overwrite each other's
    guest copy, so staging must be taken in turns.
  - The Lubuntu VM has no GNOME. Stage this effort on the Ubuntu GNOME VM
    (`z@192.168.122.242`, GNOME Shell 50.1), which AGENTS.md describes.
