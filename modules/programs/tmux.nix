{ config, pkgs, ... }:

let
  configRoot = "${config.home.homeDirectory}/Documents/dotfiles/configs/tmux";
in
{
  # This module owns the tmux package, but not through programs.tmux: that
  # option generates ~/.config/tmux/tmux.conf itself, and this configuration is
  # a native file the operator edits and reloads with `prefix + r`. The two
  # cannot both own that path, and the generated half would only contribute
  # defaults nobody wrote. Nix still owns the plugins — see below — so the only
  # thing given up is the generator.
  home.packages = [ pkgs.tmux ];

  xdg.configFile."tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${configRoot}/tmux.conf";

  # Three plugins, each packaged in Nixpkgs. TPM would cost a network fetch and
  # a manual `prefix + I` on every fresh machine, which is a bad trade for a set
  # this small and this stable; a plugin is only a directory of shell scripts,
  # so installing one means putting that directory where tmux.conf can name it.
  #
  # The link names are the upstream repository names rather than the Nixpkgs
  # attribute names, because that is the layout TPM produced and the layout the
  # bindings in tmux.conf are already written against.
  xdg.configFile."tmux/plugins/tmux-sensible".source =
    "${pkgs.tmuxPlugins.sensible}/share/tmux-plugins/sensible";

  xdg.configFile."tmux/plugins/tmux-resurrect".source =
    "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect";

  xdg.configFile."tmux/plugins/tmux-continuum".source =
    "${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum";
}
