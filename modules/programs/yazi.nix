{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/yazi";

  copy-file-contents = pkgs.callPackage ../../packages/yazi-copy-file-contents.nix {
    inherit (pkgs.yaziPlugins) mkYaziPlugin;
  };
in
{
  # programs.yazi owns the package and places each plugin where Yazi looks for
  # it, at ~/.config/yazi/plugins/<name>.yazi. keymap.toml stays native and
  # live-editable: Yazi re-reads it on restart, and it is the file the operator
  # actually touches.
  programs.yazi = {
    enable = true;

    # Nix owns both plugins rather than `ya pkg`, which would need a network
    # fetch on every fresh machine.
    plugins = {
      # Puts the selected files themselves on the system clipboard as
      # `text/uri-list`, which is what makes a GUI application paste a file
      # rather than a path string. Nixpkgs carries it and keeps it current, so
      # there is no local package and no second record of its revision.
      #
      # It shells out to `wl-copy`/`wl-paste` on Wayland and `xclip` on X11,
      # choosing by `XDG_SESSION_TYPE`; both are global user tools.
      clipboard = pkgs.yaziPlugins.clipboard;

      # Copies what is inside the files instead. Each key binding passes its own
      # `plain` or `multi` argument, so `setup` only has to turn the
      # notification on — which doubles as the visible proof the plugin loaded,
      # since a plugin in the wrong place fails quietly.
      copy-file-contents = {
        package = copy-file-contents;
        setup = true;
        settings.notification = true;
      };
    };
  };

  xdg.configFile."yazi/keymap.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/keymap.toml";

  # package.toml is `ya pkg`'s manifest, and Nix has taken that job over. It
  # stays in the repository as the record of which revision of
  # copy-file-contents was selected, which packages/yazi-copy-file-contents.nix
  # cites, but it is deliberately not linked into the config directory: nothing
  # reads it there, and a stray `ya pkg upgrade` would only fail against a
  # plugin directory Nix owns. It lists only that plugin, because Nixpkgs is
  # already the record for the other one.
}
