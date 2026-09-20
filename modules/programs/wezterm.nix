{ config, lib, pkgs, ... }:

let
  wezterm-console = pkgs.callPackage ../../packages/wezterm-console { };
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/wezterm";
in
{
  # Like tmux, this owns the package but not through programs.wezterm, which
  # generates wezterm.lua itself. The config is a native Lua file that WezTerm
  # reloads on save, so it stays live-editable in configs/wezterm.
  home.packages = [ pkgs.wezterm ];

  xdg.configFile."wezterm/wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/wezterm.lua";


  # Nautilus's "Open in Console" (Ctrl+.) is not a terminal preference: it
  # calls org.freedesktop.Application.Open on the D-Bus name org.gnome.Ptyxis
  # (GNOME Console upstream; Fedora patches the name) and hides the item when
  # that name is not activatable. A service file in the user's data directory
  # takes precedence over the host's, so wezterm-console answers the name and
  # opens WezTerm there instead. GNOME's Ptyxis launcher is DBusActivatable
  # and reaches the same service, so Ptyxis is replaced everywhere, not just
  # in Nautilus.
  xdg.dataFile."dbus-1/services/org.gnome.Ptyxis.service".text = ''
    [D-BUS Service]
    Name=org.gnome.Ptyxis
    Exec=${lib.getExe wezterm-console}
  '';
}
