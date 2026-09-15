# 05 — Extensions and GNOME tools

Type: task
Status: resolved

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

## Answer

Landed in `modules/desktops/gnome.nix` and `home.nix`. The design changes
from the ticket are described under Comments.

Verified 2026-09-15:

- **Host:** `nix flake check` passes, and `homeConfigurations.z.activationPackage`
  builds. The generated dconf INI holds exactly `enabled-extensions` (the three
  Nix UUIDs), `disabled-extensions = ['ding@rastersoft.com']` and
  `disable-user-extensions = false`.
- **Activation on the Ubuntu GNOME VM** (Ubuntu 26.04.1, GNOME Shell 50.1,
  Wayland), through `bootstrap.sh install home-manager` as `staging`:
  - Over non-interactive `ssh` it wrote the three keys, and `gsettings` read
    them back. `sops-nix` and `sing-box` failed only because secret recovery
    was not run on the VM.
  - The running session did not load the extensions. They appeared only after
    a real GDM re-login, as expected, because `XDG_DATA_DIRS` comes from
    `environment.d` at login.
  - Reading the running session while the screen was locked showed no enabled
    extensions at all, because the lock screen's session mode disables them.
    Check with the session unlocked.
- **After re-login:**
  - The `gnome-shell` environment's `XDG_DATA_DIRS` contains
    `/home/z/.nix-profile/share`.
  - `gnome-extensions list --enabled` shows blur-my-shell, clipboard-indicator,
    hidetopbar, snapd-prompting, snapd-search-provider, tiling-assistant,
    ubuntu-appindicators, ubuntu-dock and web-search-provider.
  - `ding` is `INITIALIZED` rather than active, so `disabled-extensions` does
    override the session mode.
  - The three Nix extensions are `ACTIVE`, loaded from their symlinked
    `~/.nix-profile/share/gnome-shell/extensions/<uuid>` paths. GNOME Shell 50
    follows the symlinks.
  - On screen: Ubuntu Dock present, top bar hidden, no desktop icons.
- **Tools, launched in the session:**
  - GNOME Tweaks 49.0 (Nix) opens against Shell 50.1, with only the upstream
    "Extensions Has Moved" notice.
  - Extension Manager lists all ten extensions with the correct toggles, the
    Nix ones under "System Extensions".
  - dconf Editor opens.
  - blur-my-shell's preferences open through `gnome-extensions prefs`.
  - No gnome-shell errors were logged.
- **Benign log line:** gnome-shell logs "Extension … already installed in
  <path>. <path> will not be loaded" once per Nix extension. The two paths are
  identical, because the Nix installer's `/etc/profile.d/nix.sh` appends
  `~/.nix-profile/share` to `XDG_DATA_DIRS` a second time. See ticket 03's
  comments.

Not verified here: the new PC under normal use, and Fedora, whose GNOME has no
Ubuntu session mode (the `ding` entry is then inert).

## Comments

2026-09-15, agent:

- **Ubuntu defaults need no entries.** On the fresh Ubuntu GNOME VM,
  `enabled-extensions` is `[]`, yet all seven distro extensions run. They
  come from `enabledExtensions` in `/usr/share/gnome-shell/modes/ubuntu.json`:
  `ubuntu-dock`, `ubuntu-appindicators`, `ding`, `tiling-assistant`,
  `snapd-prompting`, `snapd-search-provider` and `web-search-provider`. The
  session mode enables them whatever `enabled-extensions` holds, so step 2's
  id-only entries are dropped, and `programs.gnome-shell.extensions` lists
  only the three Nix packages. `snapd-prompting` wasn't in the current PC's
  list, which is another reason not to hard-code the distro's set. As a
  result the acceptance count is ten enabled (seven distro plus three Nix)
  minus `ding`, not "all eight".
- **`targets.genericLinux` lives in `home.nix`.** It isn't GNOME-specific: it
  also changes zsh `fpath`, `TERMINFO_DIRS`, `NIX_PATH`, `XCURSOR_PATH`, and
  sources nixpkgs' `nix.sh` from `hm-session-vars.sh`. `gpu.enable = false`
  sits next to it.
- **Tools come from Nixpkgs.** The operator's machines span Ubuntu, Fedora and
  possibly NixOS, so a per-distro install is worse than closure size.
  `gnome-tweaks` alone adds about 851 MiB, because it carries its own
  `gnome-shell`, `mutter`, WebKitGTK and IBus. `dconf-editor` adds 5 MiB and
  `gnome-extension-manager` 2 MiB. The operator accepted the size unless the
  Nix build proves unreliable against the distro's Shell, which is checked on
  the VM.
