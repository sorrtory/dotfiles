# 04 — Mutter, dock and appearance

Type: task
Status: needs-triage
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

## Acceptance

After host activation, the dock and window behavior match their values
before activation, with nothing visibly changed that wasn't decided in 01.

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
