{ lib }:

# A Vencord theme from a resolved theme, for Vesktop. Discord names a few
# hundred semantic tokens — `--background-primary`, `--text-muted`,
# `--bg-surface-raised` — but every one of them is `var(--primary-600)` or
# `hsl(var(--primary-500-hsl)/0.3)`: numbered steps of a handful of color
# families declared in `:root`, which the `.theme-dark` class only maps onto.
# So this writes the families, not the tokens. Every token follows, including
# the ones this file has never heard of and the ones Discord renames next
# week, and the translucent overlays Discord mixes itself keep working
# because each step is written as its hsl triple as well as its hex.
#
# A step's number is its lightness, from 100 at the near-white end to 900 at
# black. That is our roles' own order — text, subtext, muted, overlay,
# surface, base, mantle — so the neutral family below is that walk, and each
# colored one is a single role dropped where Discord reads it with the stock
# ramp transposed around it.
#
# Solid colors only. Vencord can make the window itself translucent, but that
# is Chromium on GNOME Wayland, which redraws a transparent window with
# glitches while it moves, and Vencord's switch also stops the window being
# resizable. The transparency switch reaches Vesktop from outside instead,
# through Blur my Shell in desktops/gnome.nix, as it does for Obsidian.

colors:
let
  inherit (import ./color.nix { inherit lib; }) mix hsl;
  inherit (colors) base mantle surface overlay text subtext muted accent accent2 error warning success;

  white = "#ffffff";
  black = "#000000";

  # The neutral family, anchored on the roles: the steps Discord reads as
  # text at the top, the ones it fills panels with at the bottom, and mixes
  # in between. 600 is the window, 630 the channel list, 700 the server bar,
  # 800 what floats above them; 560 is the message box, a shade above the
  # window, and 500 is both the disabled glyph and the wash Discord lightens
  # a hovered or selected row with.
  primary = {
    "100" = mix text white 0.5;
    "130" = mix text white 0.25;
    "160" = mix text white 0.15;
    "200" = mix text white 0.07;
    "230" = text;
    "260" = mix text subtext 0.3;
    "300" = mix text subtext 0.7;
    "330" = subtext;
    "345" = mix subtext muted 0.5;
    "360" = muted;
    "400" = mix muted overlay 0.35;
    "430" = mix muted overlay 0.6;
    "460" = mix muted overlay 0.8;
    "500" = overlay;
    "530" = mix overlay surface 0.5;
    "560" = surface;
    "600" = base;
    "630" = mix base mantle 0.5;
    "645" = mix base mantle 0.7;
    "660" = mantle;
    "700" = mix mantle black 0.15;
    "730" = mix mantle black 0.25;
    "760" = mix mantle black 0.35;
    "800" = mix mantle black 0.45;
    "830" = mix mantle black 0.6;
    "860" = mix mantle black 0.8;
    "900" = mix mantle black 0.95;
  };

  # Discord's own colored ramp, as the lightness of each step of its blurple
  # family. A family is one of our colors put where Discord reads it and the
  # rest of the ramp transposed onto it: every lighter step is that color
  # mixed toward white, every darker one toward black, each by the distance
  # the stock ramp keeps. 645 is Discord's alone; it fills the gap so a
  # family is never asked for a step it does not have.
  lightness = {
    "100" = 98.2; "130" = 96.9; "160" = 94.9; "200" = 92.9; "230" = 91.0;
    "260" = 88.6; "300" = 85.9; "330" = 81.6; "345" = 78.8; "360" = 77.5;
    "400" = 71.8; "430" = 69.8; "460" = 67.5; "500" = 64.7;
    "530" = 58.8; "560" = 52.4; "600" = 44.1; "630" = 38.2; "645" = 35.7;
    "660" = 33.3; "700" = 25.9; "730" = 24.3; "760" = 22.2; "800" = 19.4;
    "830" = 14.9; "860" = 9.6; "900" = 3.1;
  };

  family = step: hex:
    let anchor = lightness.${step}; in
    lib.mapAttrs
      (_: level:
        if level >= anchor
        then mix hex white ((level - anchor) / (100.0 - anchor))
        else mix hex black (1.0 - level / anchor))
      lightness;

  # Where each color belongs in that ramp. The accent is what a button is
  # painted with, so it goes at 500, where Discord paints its own and where
  # white text is meant to sit on top of it. The other four are colors this
  # palette means to be read on a dark panel, so they go at 360, where
  # Discord reads them as text, and the darker step a filled button uses
  # falls out of the ramp below them.
  families = {
    inherit primary;
    brand = family "500" accent;
    blue = family "360" accent2;
    red = family "360" error;
    yellow = family "360" warning;
    green = family "360" success;
  };

  # Each step twice: the hex, which is exact, and the triple Discord builds
  # its translucent washes from, which is the same color rounded to the whole
  # degrees and percents that format is written in. `--saturation-factor` is
  # Discord's own saturation slider, kept working rather than flattened.
  declare = name: step: hex:
    let color = hsl hex; in
    "  --${name}-${step}: ${hex};\n"
    + "  --${name}-${step}-hsl: ${toString color.h} calc(var(--saturation-factor, 1) * ${toString color.s}%) ${toString color.l}%;\n";

  declarations = lib.concatStrings (lib.mapAttrsToList
    (name: shades: lib.concatStrings (lib.mapAttrsToList (declare name) shades))
    families);

  # A palette's escape hatch for a token no family reaches, written as it
  # would be in the stylesheet: `variables."--text-link" = "#83a598";`.
  variables = lib.concatStrings
    (lib.mapAttrsToList (name: value: "  ${name}: ${value};\n") (colors.variables or { }));
in
''
  /**
   * @name Dotfiles
   * @description Generated from the theme in home.nix; see modules/theme.
   * @author modules/theme/vesktop-theme.nix
   * @version 1.0.0
   */

  /* Edits here are replaced at the next Home Manager activation. */

'' + ":root {\n" + declarations + variables + "}\n"
