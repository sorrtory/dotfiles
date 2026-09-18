{ config, lib, pkgs, spicetify-nix, ... }:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  # Spotify needs only TCP, so like Obsidian it takes the local HTTP proxy
  # rather than the VPN. Its Chromium shell honours the flag, which scopes the
  # proxy to this process, never the session. Spicetify builds on top of this
  # derivation with overrideAttrs, so the flag is added in postFixup, after
  # the nixpkgs wrapper exists, instead of wrapping the result.
  spotify = pkgs.spotify.overrideAttrs (old: lib.optionalAttrs config.dotfiles.localProxy.enable {
    postFixup = (old.postFixup or "") + ''
      wrapProgramShell $out/share/spotify/spotify \
        --add-flags "--proxy-server=http://127.0.0.1:3128"
    '';
  });
in
{
  imports = [ spicetify-nix.homeManagerModules.spicetify ];

  # Login and session state stay machine-local in ~/.config/spotify.
  programs.spicetify = {
    enable = true;
    spotifyPackage = spotify;
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
    ];

    # AyuGram's Autumn Glass palette (configs/ayugram/autumn-glass): espresso
    # surfaces, parchment text and copper accents, without its alpha, which
    # Spotify can't use. A change to that theme needs these updating too.
    colorScheme = "custom";
    customColorScheme = {
      text = "f6e9da";
      subtext = "bda18e";
      main = "261814";
      main-elevated = "34231e";
      sidebar = "1d1210";
      player = "1d1210";
      card = "3a251f";
      shadow = "0f0907";
      selected-row = "f6e9da";
      button = "e9a15e";
      button-active = "c86138";
      button-disabled = "957c6e";
      tab-active = "c86138";
      notification = "3a251f";
      notification-error = "e96b58";
      misc = "725046";
      highlight = "4a3028";
      highlight-elevated = "5a392f";
    };

    # The Default theme is stock Spotify's layout, recoloured by the scheme
    # above. Transparency comes from Blur my Shell in desktops/gnome.nix.
    theme = spicePkgs.themes.default;
  };
}
