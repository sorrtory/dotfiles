{ config, lib, pkgs, spicetify-nix, ... }:

let
  spicePkgs = spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};

  theme = config.dotfiles.theme;

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

    # The scheme comes from the palette in home.nix (modules/theme). Spotify
    # reads it once at startup, and Spicetify bakes it into the client's CSS
    # at activation, so a switch shows up at the next launch.
    colorScheme = "custom";
    customColorScheme =
      import ../theme/spotify-scheme.nix { inherit lib; } (theme.forApp "spotify");

    # The Default theme is stock Spotify's layout, recoloured by the scheme
    # above. Transparency comes from Blur my Shell in desktops/gnome.nix.
    theme = spicePkgs.themes.default;
  };

  dotfiles.theme.apps.spotify = {
    label = "Spotify";
    apply = "restart";
  };
}
