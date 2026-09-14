# 03 — Launchers and keybindings

Type: task
Status: ready-for-agent

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
