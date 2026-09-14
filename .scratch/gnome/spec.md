# Spec: GNOME preferences

Status: needs-triage

## Why

Migration plan §9: move intentional GNOME preferences into the user
environment through `modules/desktops/gnome.nix`, capturing current dconf state
as evidence, keeping deliberate preferences and dropping incidental runtime
keys. The legacy `setup_gnome` in `~/Documents/scripts/install.sh` replays
`GSETTINGS_CMDS`, appends `CUSTOM_LAUNCHERS` and installs extensions, all
driven by `install.conf`. It isn't idempotent, and the host has drifted from it.

The operator wants the keyboard settled first: Caps Lock is Escape,
Shift+Caps Lock is the old Caps Lock, and Alt+Shift switches layout.

## Evidence

Gathered 2026-09-15. The host is Ubuntu 26.04.1 with GNOME Shell 50.1 on
Wayland and xkb-data 2.46. The legacy source is `~/Documents/scripts` at
`86867ce`.

### Keyboard

| Key (`org/gnome/desktop/input-sources`) | `install.conf` | Host dconf |
| --- | --- | --- |
| `sources` | `[('xkb','us'), ('xkb','ru')]` | same |
| `xkb-options` | `['grp:alt_shift_toggle']` | `['grp:alt_shift_toggle', 'caps:escape_shifted_capslock']` |

- Both options exist in xkb-data on the host (2.46) and on the VM (2.41).
  `caps:escape_shifted_capslock` maps `<CAPS>` to
  `[ Escape, Caps_Lock ]` with `LockMods(Lock)` on level 2, which is exactly
  the requested behavior. There is also `caps:escape`, where Caps Lock is
  only Escape.
- `xkb-options` is a single string list. Setting it replaces the whole list,
  so rerunning the legacy command would silently drop the Caps option. The
  host, not `install.conf`, is the baseline for this key.
- GNOME's own switcher is still bound:
  `org/gnome/desktop/wm/keybindings switch-input-source = ['<Super>space', 'XF86Keyboard']`
  (the default). The XKB `grp:` toggle is a second, independent switcher.
- `/etc/default/keyboard` has `XKBOPTIONS=""`. The console and GDM keymap are
  host-owned and untouched by the dconf keys.
- Unverified: how Mutter on Wayland treats `grp:alt_shift_toggle`. Open
  questions are whether it fires on press or release, whether it swallows
  Alt+Shift+key shortcuts, and whether the panel indicator follows it. The
  operator uses it daily, so this is a normal-use question, not a blocker.

The equivalent imperative commands:

```sh
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:alt_shift_toggle', 'caps:escape_shifted_capslock']"
```

The declarative form under this repository's policy
(`DECISIONS.md`: "GNOME should use `dconf.settings` where practical"):

```nix
dconf.settings."org/gnome/desktop/input-sources" = with lib.hm.gvariant; {
  sources = [ (mkTuple [ "xkb" "us" ]) (mkTuple [ "xkb" "ru" ]) ];
  xkb-options = [ "grp:alt_shift_toggle" "caps:escape_shifted_capslock" ];
};
```

### Other legacy `GSETTINGS_CMDS` compared with the host

| Area | Legacy | Host drift |
| --- | --- | --- |
| `org/gnome/mutter` | `center-new-windows=true` | Also `edge-tiling=false`, `workspaces-only-on-primary=true`, `keybindings/toggle-tiled-left,right=[]` |
| `org/gnome/desktop/wm/keybindings` | `close <Super>q`; workspace moves `<Control><Super>Left/Right`; workspace switches `<Control><Alt>Left/Right` | Matches |
| `org/gnome/shell/keybindings` | `focus-active-notification`, `toggle-quick-settings` = `['disabled']` | Also `toggle-message-tray=[]` |
| `org/gnome/shell/extensions/dash-to-dock` | centered icons, no apps button or trash, minimize on click, `hot-keys=false`, autohide and intellihide over all windows, extended height | Also `dock-position='LEFT'`, `transparency-mode='FIXED'`, `background-opacity=0.0`, `dash-max-icon-size=48`, `height-fraction=0.9`, `preferred-monitor=-2`, `preferred-monitor-by-connector='eDP-1'` (machine-specific), `isolate-*=false` |
| `org/gnome/desktop/interface` | All commented out | `color-scheme='prefer-dark'`, `gtk-theme` and `icon-theme` `'Yaru-sage-dark'`, `accent-color='slate'` |
| Desktop icons | `gnome-extensions disable ding@rastersoft.com` | `ding` is in `disabled-extensions` |

### Custom launchers (`org/gnome/settings-daemon/plugins/media-keys`)

The legacy `append_keybindings` writes one relocatable
`custom-keybinding` per `CUSTOM_LAUNCHERS` entry. It appends the path to
`custom-keybindings` with no deduplication, so a rerun duplicates entries.
Host state:

| Path | Binding | Command | Compared with legacy |
| --- | --- | --- | --- |
| `firefox` | `<Super>f` | `firefox` | same |
| `code` | `<Super>c` | `code` | same |
| `typing` | `<Super>t` | `subl` | same |
| `obsidian` | `<Super>n` | `obsidian` | same (Obsidian config itself was dropped) |
| `explorer` | `<Super>e` | `nautilus -w` | same |
| `spotify` | `<Super>s` | `gtk-launch spotify.desktop` | legacy ran `spotify` |
| `custom0` | `<Shift>F11` | `flatpak run be.alexandervanhee.gradia --screenshot=INTERACTIVE` | legacy path was `gradia`; recreated in the GUI |
| `custom1` | `<Super>m` | `/home/z/.local/bin/telegram-desktop` | legacy TODO, added in the GUI |

### Extensions

- Legacy installs blur-my-shell, clipboard-indicator and hidetopbar through
  the archived `gnome-shell-extension-installer`, which `sudo mv`s itself into
  `/usr/bin`. Enabling is left manual.
- Host `enabled-extensions` holds those three plus Ubuntu's defaults
  (`tiling-assistant`, `ubuntu-dock`, `snapd-search-provider`,
  `web-search-provider`). Declaring this key replaces the whole list,
  distro defaults included.
- `gnome-tweaks`, `gnome-shell-extension-manager` and `dconf-editor` were apt
  packages in `install.conf`. `docs/SOFTWARE.md` defers all three to this
  migration.

### Home Manager `dconf` module (pinned `65258d5`)

- Activation runs `dconf load /` from a generated INI after `installPackages`.
  No `sudo` is involved.
- Only declared keys are written. A key removed from the configuration is
  `dconf reset` on the next switch, tracked through the generation's
  `state/dconf-keys.json`. Keys never declared are left alone.
- With no `DBUS_SESSION_BUS_ADDRESS`, as in a non-interactive `ssh` or bootstrap
  run, it wraps the call in a private `dbus-run-session`. Unverified: whether
  an already-running GNOME session notices a write made that way without
  re-login.
- Types are strict: tuples need `lib.hm.gvariant.mkTuple`, empty lists
  `mkEmptyArray`. Relocatable custom keybindings are ordinary
  `"org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/<name>"`
  paths.

### Non-NixOS reachability (host, 2026-09-15)

- The host has never activated Home Manager: there is no `~/.nix-profile` and
  no Home Manager state. Every launcher command resolves to apt or snap under
  `/usr/bin`, or to `~/.local/bin/telegram-desktop`.
- `gnome-shell` and `gsd-media-keys` run with exactly the systemd user
  manager's environment. That environment has no Nix path in `PATH` or in
  `XDG_DATA_DIRS`, although `/etc/profile.d/nix.sh` exists. GNOME Shell was
  started 2026-09-14, well after Nix was installed on 2026-08-18.
- Consequence for launchers: a dconf `command` naming a bare Nix-provided
  binary would not be found. Either use absolute store paths
  (`${pkgs.x}/bin/x`) or add the profile to the session `PATH`.
- Consequence for extensions: Home Manager's `programs.gnome-shell.extensions`
  sets `enabled-extensions` and adds the packages to `home.packages`, which
  puts them in `~/.nix-profile/share/gnome-shell/extensions`. GNOME Shell
  finds them only if that `share` directory is in `XDG_DATA_DIRS`, or if they
  are linked into `~/.local/share/gnome-shell/extensions/<uuid>`.
- `targets.genericLinux.enable` adds `~/.nix-profile/share` to
  `xdg.systemDirs.data`. Home Manager writes those directories to both
  `hm-session-vars.sh` and `systemd.user.sessionVariables`, which becomes
  `~/.config/environment.d/10-home-manager.conf`, and the GNOME session
  inherits that at login. The same target turns on
  `targets.genericLinux.gpu` by default, which `docs/DECISIONS.md` rejected
  because of its root-owned `/run/opengl-driver`. It would need
  `gpu.enable = false`.
- In pinned Nixpkgs (`nixos-26.05`, GNOME Shell 50.4), `gnomeExtensions`
  has blur-my-shell 72, clipboard-indicator 71 and hide-top-bar 124. All
  declare shell-version 50 and ship `schemas/gschemas.compiled`. The host has
  72, 71 and 125, as real directories under
  `~/.local/share/gnome-shell/extensions`. Home Manager will refuse to
  replace those directories with links until they are moved aside.
- Extension settings already live in dconf under
  `org/gnome/shell/extensions/{blur-my-shell/*,hidetopbar,dash-to-dock,tiling-assistant,ding}`.
- Unverified: whether GNOME Shell 50 follows a symlinked extension
  directory, and whether a newly installed extension appears without
  re-login on Wayland.

### Staging VM

- Lubuntu 24.04 with LXQt on X11 through SDDM. `gnome-shell` is not installed,
  though 46.0 is available from apt.
- `dconf-service`, the dconf GSettings backend and
  `gsettings-desktop-schemas` 46.1 are present, and `input-sources` keys are
  writable, so a Home Manager write can be read back. `dconf` CLI is absent,
  though Home Manager brings its own. Whether the Mutter, Shell and
  dash-to-dock schemas exist there has not been checked.
- There is no Home Manager generation and no mirrored tree at
  `~/Documents/dotfiles`. The guest looks reset and needs a bootstrap before
  it can stage anything.
- LXQt ignores GNOME's input-sources, so the VM can show that keys land, but
  not that the keyboard behaves.

## Target

The current PC is evidence only, and nothing here is switched on it. The
slice is realised on a fresh Ubuntu install on a new PC, where it should
reproduce the current GNOME experience.

## Open questions

Settled in ticket 01 (see its Answer). Kept for the record:

1. Declarative `dconf.settings`, per the existing decision, or a bootstrap
   phase replaying `gsettings` commands? A trade-off to weigh: Home Manager
   resets keys dropped from the configuration and reapplies on every switch,
   overwriting GUI tweaks to managed keys.
2. Which drifted host values are deliberate? These are the Mutter tiling
   keys, `toggle-message-tray`, the dock geometry and transparency, and the
   appearance keys.
3. `caps:escape_shifted_capslock` or `caps:escape`?
4. Keep GNOME's `<Super>space` switcher alongside Alt+Shift, or clear it?
5. Launchers: keep all eight? Choose stable path names in place of `custom0`
   and `custom1`. Should launcher commands point at Nix-provided binaries
   where they exist, such as `subl` and `code`?
6. Extensions: should the user environment own `enabled-extensions` and the
   extension files, or should the host keep them? Is there a Nixpkgs
   `gnomeExtensions.*` path for the three, and does it work with a
   distro-installed GNOME Shell?
7. Verification: install `gnome-shell` on the VM, or prove keys land on the
   VM and judge behavior on the host only?
8. Does activation over `ssh` need a re-login before a running GNOME session
   picks up changes?

## Scope

In scope: `modules/desktops/gnome.nix`, its import in `home.nix`, the dconf
keys above as settled, and the documentation rows they change.
`docs/SOFTWARE.md` has the three GNOME tools, and `docs/DECISIONS.md` and
`docs/MIGRATION.md` §9 are affected too.

Out of scope: GDM, the console keymap and `/etc/default/keyboard`, which
are host-owned, as well as Hyprland and installing GNOME itself.

## Definition of done

- `nix flake check` and the activation package build succeed.
- On the staging VM, activation writes each declared key, and `dconf read`
  returns the declared value.
- On an Ubuntu GNOME VM, then the new PC: Caps Lock types Escape,
  Shift+Caps Lock toggles Caps Lock, and Alt+Shift switches us⇄ru. Each
  launcher and keybinding fires, and the declared extensions are enabled
  without errors.
- The legacy `setup_gnome` path is not retired until the replacement has
  survived normal use.
