{ config, lib, pkgs, ... }:

let
  configRoot =
    "${config.home.homeDirectory}/Documents/dotfiles/configs/sublime-text";
  packageControl = pkgs.fetchurl {
    url = "https://github.com/sublimehq/package_control/releases/download/4.2.8/Package.Control.sublime-package";
    hash = "sha256-jhRvM6SOfELkouk7Dz+f4iguf8u63ZtQL++F0V8FX4M=";
  };
  # Both plugin hosts of build 4200 link OpenSSL 1.1. Nixpkgs' copy is marked
  # insecure, so Hydra never caches it and every pin bump compiled it from
  # source; the tarball already ships the same runtime, so link that instead.
  # Remove this override, the wrapper's SSL_CERT_FILE with it, once the stable
  # pin's sublime4 is build 4205 or later: its plugin host links OpenSSL 3.
  vendoredOpenssl = pkgs.stdenv.mkDerivation {
    pname = "sublimetext4-vendored-openssl";
    inherit (pkgs.sublime4) version;
    src = pkgs.sublime4.unwrapped.src;
    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    installPhase = ''
      install -Dm755 -t "$out/lib" libssl.so.1.1 libcrypto.so.1.1
    '';
  };
  sublime4 = (pkgs.sublime4.override { openssl_1_1 = vendoredOpenssl; })
    .overrideAttrs (old: {
      # The vendored OpenSSL looks for CA certificates under a sublimehq build
      # prefix that exists on no machine, so plugins' HTTPS needs a bundle.
      postFixup = (old.postFixup or "") + ''
        wrapProgram "$out/bin/sublime_text" \
          --set-default SSL_CERT_FILE "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      '';
    });
  theme = config.dotfiles.theme;
  # Terminus calls yellow "brown" and prefixes bright ANSI slots with
  # "light_". Its settings watcher rebuilds the hidden color scheme when
  # user_theme_colors changes, including for open terminal views.
  terminusAnsiKeys = {
    black = "black";
    red = "red";
    green = "green";
    brown = "yellow";
    blue = "blue";
    magenta = "magenta";
    cyan = "cyan";
    white = "white";
    light_black = "brightBlack";
    light_red = "brightRed";
    light_green = "brightGreen";
    light_brown = "brightYellow";
    light_blue = "brightBlue";
    light_magenta = "brightMagenta";
    light_cyan = "brightCyan";
    light_white = "brightWhite";
  };
  terminusSettings = colors: builtins.toJSON {
    theme = "user";
    user_theme_colors = {
      background = colors.base;
      foreground = colors.text;
      caret = colors.accent;
      block_caret = colors.accent;
      selection = colors.overlay;
      selection_foreground = colors.text;
    } // builtins.mapAttrs (_: role: colors.${role}) terminusAnsiKeys;
  };
  terminusCache = "${config.xdg.configHome}/sublime-text/Packages/User/Terminus/Terminus.hidden-color-scheme";
in
{
  home.packages = [ sublime4 ];

  # Sublime rereads a color scheme in Packages/User when its file changes, so
  # a switch recolors an open window. The name never changes; what is behind
  # it does.
  dotfiles.theme.liveFiles."${config.xdg.configHome}/sublime-text/Packages/User/Dotfiles.sublime-color-scheme" =
    pkgs.writeText "Dotfiles.sublime-color-scheme"
      (import ../theme/sublime-scheme.nix { inherit lib; } (theme.forApp "sublime-text"));
  dotfiles.theme.apps.sublime-text = {
    label = "Sublime Text";
    apply = "live";
  };
  dotfiles.theme.liveFiles."${config.xdg.configHome}/sublime-text/Packages/User/Terminus.sublime-settings" =
    pkgs.writeText "Terminus.sublime-settings"
      (terminusSettings (theme.forApp "terminus"));
  dotfiles.theme.apps.terminus = {
    label = "Terminus";
    apply = "live";
  };
  # When Sublime was closed during the switch, Terminus would keep an old
  # hidden scheme at next startup and skip regeneration merely because that
  # file exists. Invalidate it before the new settings file is written. A
  # running Terminus also watches the settings change and rebuilds the scheme.
  home.activation.invalidateTerminusCache = lib.hm.dag.entryBetween
    [ "dotfilesThemeFiles" ] [ "dotfilesThemeInit" ] ''
      if (( dotfilesThemeChanged )); then
        run rm -f ${lib.escapeShellArg terminusCache}
      fi
    '';

  xdg.configFile = lib.genAttrs (map (name: "sublime-text/Packages/User/${name}") [
    "Preferences.sublime-settings"
    "Default (Linux).sublime-keymap"
    "Package Control.sublime-settings"
    "Terminus View.sublime-settings"
  ]) (target: {
    source = config.lib.file.mkOutOfStoreSymlink
      "${configRoot}/${baseNameOf target}";
  }) // {
    "sublime-text/Installed Packages/Package Control.sublime-package".source =
      packageControl;
  };
}
