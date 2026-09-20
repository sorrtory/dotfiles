{ lib }:

# A Spicetify color scheme from a resolved theme. Spicetify takes eighteen
# named slots and writes them into Spotify's own CSS variables, so this is the
# whole of what the client looks like once the Default theme lays it out.
#
# Spicetify wants bare hex digits, without the leading `#`.
#
# Four of the slots ask for a surface no role names — a card, its shadow, a
# hover fill above the selection, and the neutral "misc" line — so they are
# steps between two roles rather than roles. A palette that wants a different
# value for one of them says so in `overrides.spotify.scheme`, which is this
# app's escape hatch for its own key names, as `highlights` is for Neovim.

colors:
let
  inherit (import ./color.nix { inherit lib; }) mix;
  inherit (colors) base mantle surface overlay text subtext muted accent accent2 error;

  bare = hex: lib.removePrefix "#" hex;

  scheme = {
    text = text;
    subtext = subtext;

    # The window, a panel raised out of it, and the two chromes that frame it.
    main = base;
    main-elevated = surface;
    sidebar = mantle;
    player = mantle;

    # A card sits a step above the raised panel, and its shadow a step below
    # the darkest surface there is.
    card = mix surface overlay 0.25;
    shadow = mix mantle "#000000" 0.5;
    notification = mix surface overlay 0.25;
    notification-error = error;

    # Controls. The resting button is the second accent, and pressing it or
    # selecting a tab brings the first one out.
    button = accent2;
    button-active = accent;
    button-disabled = muted;
    tab-active = accent;
    selected-row = text;

    # Neutrals: separators and disabled glyphs, the selection, and the hover
    # fill drawn above a selected row.
    misc = mix overlay muted 0.5;
    highlight = overlay;
    highlight-elevated = mix overlay muted 0.25;
  } // (colors.scheme or { });
in
lib.mapAttrs (_: bare) scheme
