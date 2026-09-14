# 05 — Extensions and GNOME tools

Type: task
Status: ready-for-agent

## Goal

Install and enable blur-my-shell, clipboard-indicator and hidetopbar from
Nixpkgs, and keep Ubuntu's default extensions enabled. This replaces the
archived installer.

## Work

1. Set `targets.genericLinux.enable = true`, and
   `targets.genericLinux.gpu.enable` as the operator settles it. Until then
   it stays `false`, per the current GPU decision.
2. Set `programs.gnome-shell.enable = true`, with `extensions` holding
   `gnomeExtensions.blur-my-shell`, `clipboard-indicator` and `hide-top-bar`.
   Add id-only entries for Ubuntu's defaults: `ubuntu-dock@ubuntu.com`,
   `tiling-assistant@ubuntu.com`, `ubuntu-appindicators@ubuntu.com`,
   `snapd-search-provider@canonical.com` and
   `web-search-provider@ubuntu.com`. The module needs a package per entry, so
   decide how to express distro-provided ones, for example appending to
   `enabled-extensions` directly.
3. Declare `disabled-extensions = [ "ding@rastersoft.com" ]`.
4. Decide and record whether `gnome-tweaks`, `gnome-shell-extension-manager`
   and `dconf-editor` come from Nix or the host, and update their
   `docs/SOFTWARE.md` rows.

## Constraints

- Check the exact Ubuntu default extension IDs on the fresh install before
  treating this list as final. It was read from the current PC.
- Extension settings, such as blur strengths, stay unmanaged unless the
  operator asks.

## Acceptance

- `nix flake check` and the activation package build succeed.
- On a GNOME VM or the new PC, after re-login: `gnome-extensions list --enabled`
  shows all eight, the three Nix ones report no errors in
  `gnome-extensions info`, and their preferences open.

## Comments
