# 03 — Launchers and keybindings

Type: task
Status: resolved

## Goal

Declare the eight launchers plus the window and Shell keybindings, replacing
`CUSTOM_LAUNCHERS` and the non-idempotent `append_keybindings`.

## Work

1. Declare `org/gnome/settings-daemon/plugins/media-keys` `custom-keybindings`
   as the full path list. Add one `custom-keybindings/<name>` section per
   launcher, with the operator's current bindings:

   | Name | Binding | Command |
   | --- | --- | --- |
   | `firefox` | `<Super>f` | `firefox` |
   | `code` | `<Super>c` | `code` |
   | `typing` | `<Super>t` | `subl` |
   | `obsidian` | `<Super>n` | `obsidian` |
   | `explorer` | `<Super>e` | `nautilus -w` |
   | `spotify` | `<Super>s` | `spotify` or `gtk-launch spotify.desktop`, whichever works from Nix |
   | `gradia` | `<Shift>F11` | `flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE` |
   | `telegram` | `<Super>m` | `AyuGram` (ticket 06) |

2. Put the Home Manager profile's `bin` on the session `PATH` through
   `systemd.user.sessionVariables`, so plain names find Nix apps. Keep
   the distro directories after it.
3. Declare `wm/keybindings`: `close`, the `move-to-workspace-*` and
   `switch-to-workspace-*` bindings. Declare `shell/keybindings`:
   `focus-active-notification` and `toggle-quick-settings` as `['disabled']`,
   and `toggle-message-tray` as `[]`.

## Constraints

- The launcher only binds a key. Installing Firefox, Gradia and Telegram is
  outside this ticket. `docs/SOFTWARE.md` defers Firefox and Gradia, and
  Telegram has no row at all. List which bindings will do nothing on a fresh
  install until those land.
- `environment.d` is read at login, so a `PATH` change needs a re-login.

## Acceptance

- `nix flake check` and the activation package build succeed.
- `~/.config/environment.d/10-home-manager.conf` in the built generation
  carries the `PATH` and `XDG_DATA_DIRS` entries.
- On a GNOME VM or the new PC: every installed launcher opens from its key,
  and `custom-keybindings` has no duplicates.

## Answer

Landed in `modules/desktops/gnome.nix` (one launcher table generating
`custom-keybindings` and its sections, plus the WM and Shell keybindings) and
`modules/packages.nix` (`systemd.user.sessionVariables.PATH`). Names match the
table: `custom0` became `gradia` and `custom1` became `telegram`. Spotify uses
plain `spotify`, because the Nix desktop file's `Exec` is `spotify %U` and the
profile's `bin` is on the session `PATH`.

Verified 2026-09-15:

- **Host:** `nix flake check` passes, and the activation package builds.
  - The dconf INI lists all eight paths once in `custom-keybindings` and gives
    each its own section. `toggle-message-tray=@as []`, and the other two Shell
    keys are `['disabled']`.
  - `10-home-manager.conf` has `PATH=/home/z/.nix-profile/bin${PATH:+:}$PATH`
    and the `XDG_DATA_DIRS` line from 05.
- **Ubuntu GNOME VM, after a GDM re-login:**
  - `gsd-media-keys` runs with the profile's `bin` first on `PATH`, and
    `custom-keybindings` has no duplicates.
- **Launcher keys**, sent with `virsh send-key`, each checked by whether the
  process started:
  - `<Super>t` Sublime, `<Super>e` Nautilus, `<Super>s` Spotify and `<Super>f`
    Firefox (snap) all start.
  - `<Super>c` and `<Super>n` do start `code` and `obsidian`, which then abort
    in Chromium's sandbox (see Comments). That is not a launcher defect.
  - `<Super>m` (AyuGram) and `<Shift>F11` (Gradia through Flatpak) do nothing,
    as expected on a fresh install until ticket 06 and Flatpak plus Gradia
    land.
- **Window and workspace keys:**
  - `<Super>q` closes the focused window. It does so with Ubuntu Dock's default
    `hot-keys=true`, whose shortcut is also `<Super>q`.
  - `<Control><Super>Right/Left` move the focused window, and
    `<Control><Alt>Left/Right` switch workspaces. Checked with two windows
    through overview screenshots.
  - A single-window test cannot show a move. The view follows the window, and
    dynamic workspaces delete the empty one it left, so the overview looks
    unchanged.
- **Shell keybindings:** fresh GNOME's `focus-active-notification` (`<Super>n`),
  `toggle-quick-settings` (`<Super>s`) and `toggle-message-tray` (`<Super>v`,
  `<Super>m`) were the only defaults on the launcher keys. All three are
  cleared, and no other schema (system or extension) binds Control+Super+arrow.

Not verified here: the new PC under normal use.

## Comments

2026-09-15, agent, from ticket 05's staging on the Ubuntu GNOME VM:

- After a GDM login, the `gnome-shell` process and the systemd user manager
  already have `PATH=/home/z/.nix-profile/bin:/nix/var/nix/profiles/default/bin:…`,
  before this ticket adds anything. The only file that could explain it is the
  Nix installer's `/etc/profile.d/nix.sh`, which GDM's login path appears to
  source. The spec saw no Nix path in the current PC's session, so the two
  machines differ, possibly in how Nix was installed. Step 2 still makes the
  entry explicit rather than relying on the installer, and should not assume
  it is currently absent.
- Staging 03 (same VM, after re-login): `<Super>c` and `<Super>n` do spawn
  `code` and `obsidian` from the profile. Both then abort with Chromium's
  "SUID sandbox helper binary was found, but is not configured correctly"
  (`chrome-sandbox` in the Nix store cannot be setuid). Running them from a
  shell fails the same way, so the cause is not the launcher. Ubuntu has
  `kernel.apparmor_restrict_unprivileged_userns = 1`. Its shipped `code` and
  `obsidian` profiles attach to `/usr/share/code{/bin,}/code` and
  `/opt/Obsidian/obsidian`, which never match Nix paths. The repository's
  exact-path allowances (docs/VESKTOP-APPARMOR.md) cover only Vesktop and
  sing-box, and `vpn-followups/02` would extend them only to tunneled apps. So
  on a fresh Ubuntu, Nix VS Code and Obsidian cannot start at all. This is
  outside 03, and needs its own ticket and an operator decision on the
  security tradeoff.
  - Follow-up, same day: the operator chose to fix it, with both apps on the
    local HTTP proxy since they need no UDP. `modules/apparmor.nix` now
    generates `dotfiles-vscode` and `dotfiles-electron-43`.
  - After the `apparmor` phase, `<Super>c` and `<Super>n` open both windows
    with Chromium's sandbox intact, and their traffic goes to
    `127.0.0.1:3128`. Evidence is in docs/VESKTOP-APPARMOR.md.
- The same script also appends `~/.nix-profile/share` to `XDG_DATA_DIRS` after
  Home Manager's copy. That duplicate is harmless: the Shell logs "already
  installed … will not be loaded" for the same path.
