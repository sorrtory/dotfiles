# 04 — Mutter, dock and appearance

Type: task
Status: resolved
Blocked by: 01, 02

## Goal

Declare the `org/gnome/mutter`, dash-to-dock and `desktop/interface` keys kept
by 01.

## Work

1. Add the settled Mutter keys.
2. Add the settled dash-to-dock keys. Leave out monitor-specific keys unless
   01 kept them.
3. Add appearance keys if 01 kept them. The Yaru themes are distro-provided,
   so name that dependency in the module.

## Constraints

- Dash-to-dock keys only mean something with Ubuntu Dock installed. That is
  a host dependency, not something this module installs.

## Decided

Operator, 2026-09-15, asked against a fresh Ubuntu's effective defaults, read
with `XDG_CURRENT_DESKTOP=ubuntu:GNOME`. Without that variable, `gsettings`
over `ssh` shows the upstream schema values instead of Ubuntu's overrides.

- **Mutter:**
  - Declare `center-new-windows=true` and `workspaces-only-on-primary=true`.
    Both are already Ubuntu's defaults, so they matter only on other distros.
  - Drop `edge-tiling` and `toggle-tiled-left/right`, which belong to Tiling
    Assistant (see Comments).
- **Dash-to-dock:** declare the current PC's whole set, not only its
  differences from Ubuntu, so the dock is the same wherever the extension
  runs.
  - Declared: `always-center-icons=true`, `autohide=true`,
    `background-opacity=0.0`, `click-action='minimize'`,
    `dash-max-icon-size=48`, `dock-fixed=false`, `dock-position='LEFT'`,
    `extend-height=true`, `height-fraction=0.9`, `hot-keys=false`,
    `intellihide=true`, `intellihide-mode='ALL_WINDOWS'`,
    `isolate-monitors=false`, `isolate-workspaces=false`,
    `show-show-apps-button=false`, `show-trash=false` and
    `transparency-mode='FIXED'`.
  - Dropped as monitor-specific: `preferred-monitor` and
    `preferred-monitor-by-connector='eDP-1'`.
- **Appearance:** `color-scheme='prefer-dark'`, `accent-color='slate'`, and
  `gtk-theme` and `icon-theme` both `'Yaru-sage-dark'`. Yaru is Ubuntu-only,
  so on other distros the theme names fall back while dark mode and the accent
  still apply.
- **Interface:** `clock-show-weekday=true` and `gtk-enable-primary-paste=true`.
  The fonts and `enable-animations` already equal the defaults and stay
  undeclared.

## Acceptance

After host activation, the dock and window behavior match their values
before activation, with nothing visibly changed that wasn't decided in 01.

## Answer

Landed in `modules/desktops/gnome.nix` as the keys listed under Decided,
with comments naming the Ubuntu Dock and Yaru dependencies.

Verified 2026-09-15:

- **Host:** `nix flake check` passes, and the activation package builds. The
  dconf INI holds exactly the decided `mutter`, `dash-to-dock` and
  `desktop/interface` keys, and nothing monitor-specific.
- **Ubuntu GNOME VM, after re-login,** read with
  `XDG_CURRENT_DESKTOP=ubuntu:GNOME`:
  - Every declared key reads back at its declared value.
  - `edge-tiling` stays Tiling Assistant's, and `preferred-monitor-by-connector`
    stays Ubuntu's `'primary'`.
  - `Yaru-sage-dark` exists under `/usr/share/themes` and `/usr/share/icons`.
- **On screen:**
  - dark Yaru-sage theme
  - a transparent, auto-hiding dock on the left, with no apps button or trash
  - the top-bar clock shows the weekday

Not verified: that the dock and window behavior feel the same as on the current
PC under normal use. The acceptance's "after host activation" now means the
new PC, since the current PC is evidence only.

## Comments

2026-09-15, agent, found while staging 03:

- Some of the Mutter "host drift" in the spec is not a preference. On the
  current PC, `org/gnome/shell/extensions/tiling-assistant` has
  `overridden-settings={'org.gnome.mutter.edge-tiling': <@mb nothing>,
  'org.gnome.mutter.keybindings.toggle-tiled-left': <@mb nothing>,
  'org.gnome.mutter.keybindings.toggle-tiled-right': <@mb nothing>}`.
  Tiling Assistant disables Mutter's own tiling while it is enabled, and records
  the old values so it can restore them. So `edge-tiling=false` and
  `toggle-tiled-left/right=[]` are the extension's runtime state. Declaring
  them would fight the extension, or leave them wrong if it is ever disabled.
  Treat them as drop unless the operator says otherwise. The remaining Mutter
  keys (`center-new-windows`, `workspaces-only-on-primary`) are still open.
- On a fresh Ubuntu, Ubuntu Dock has `hot-keys=true` with `shortcut=['<Super>q']`.
  On the VM, `<Super>q` still closed the focused window with hot-keys on, so
  03 does not depend on the host's `hot-keys=false`.
