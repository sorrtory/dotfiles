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
