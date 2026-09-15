# 03 — Launchers and keybindings

Type: task
Status: claimed

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
- The same script also appends `~/.nix-profile/share` to `XDG_DATA_DIRS` after
  Home Manager's copy. That duplicate is harmless: the Shell logs "already
  installed … will not be loaded" for the same path.
