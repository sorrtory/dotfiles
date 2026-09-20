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

  xdg.configFile = lib.genAttrs (map (name: "sublime-text/Packages/User/${name}") [
    "Preferences.sublime-settings"
    "Default (Linux).sublime-keymap"
    "Package Control.sublime-settings"
    "Terminus.sublime-settings"
    "Terminus View.sublime-settings"
  ]) (target: {
    source = config.lib.file.mkOutOfStoreSymlink
      "${configRoot}/${baseNameOf target}";
  }) // {
    "sublime-text/Installed Packages/Package Control.sublime-package".source =
      packageControl;
  };
}
