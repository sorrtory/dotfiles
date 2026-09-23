{ lib }:

# A Vencord theme from a resolved theme, for Vesktop. Discord names a few
# hundred semantic tokens — `--background-base-lower`, `--text-muted`,
# `--bg-surface-raised` — but every one of them is `var(--neutral-69)` or
# `hsl(var(--opacity-12-hsl)/0.12)`: numbered steps of a handful of color
# families declared in `:root`, which the `.theme-dark` class only maps onto.
# So this writes the families, not the tokens. Every token follows, including
# the ones this file has never heard of and the ones Discord renames next
# week, and the translucent overlays Discord mixes itself keep working
# because each step is written as its hsl triple as well as its hex.
#
# Discord numbers its families twice. The older numbering runs 100 to 900,
# a step's number being its lightness from near-white to black. The visual
# refresh replaced it with a hundred-step one — `--neutral-69`, `--red-new-38`
# — and that is what `.theme-dark` reads now: 171 of its declarations come
# from the neutral family alone against 16 from the old numbered one. Both
# are written here. The old families are what a client without the refresh
# reads directly, and Discord's own `.visual-refresh` block re-derives them
# from the new ones for the component styles that still name them, so the
# block is scoped `:root:root` — a doubled pseudo-class, above the single
# class that re-derivation is written with — and a step is the color this
# file wrote whichever way the client reaches it.
#
# Solid colors only. Vencord can make the window itself translucent, but that
# is Chromium on GNOME Wayland, which redraws a transparent window with
# glitches while it moves, and Vencord's switch also stops the window being
# resizable. The transparency switch reaches Vesktop from outside instead,
# through Blur my Shell in desktops/gnome.nix, as it does for Obsidian.
#
# Left stock: `--white`, `--black`, and the gradients Discord paints its
# promotional tiles and banners with. Those are artwork rather than chrome.

colors:
let
  inherit (import ./color.nix { inherit lib; }) mix hsl;
  inherit (colors) base mantle surface overlay text subtext muted accent accent2 error warning success info;

  white = "#ffffff";
  black = "#000000";

  # The old neutral family, anchored on the roles: the steps Discord reads as
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

  # Discord's own colored ramp, as the lightness of each step of its old
  # blurple family. A family is one of our colors put where Discord reads it
  # and the rest of the ramp transposed onto it: every lighter step is that
  # color mixed toward white, every darker one toward black, each by the
  # distance the stock ramp keeps. 645 is Discord's alone; it fills the gap
  # so a family is never asked for a step it does not have.
  lightness = {
    "100" = 98.2; "130" = 96.9; "160" = 94.9; "200" = 92.9; "230" = 91.0;
    "260" = 88.6; "300" = 85.9; "330" = 81.6; "345" = 78.8; "360" = 77.5;
    "400" = 71.8; "430" = 69.8; "460" = 67.5; "500" = 64.7;
    "530" = 58.8; "560" = 52.4; "600" = 44.1; "630" = 38.2; "645" = 35.7;
    "660" = 33.3; "700" = 25.9; "730" = 24.3; "760" = 22.2; "800" = 19.4;
    "830" = 14.9; "860" = 9.6; "900" = 3.1;
  };

  # The seven-step ramp Discord's illustration colors walk, which the bright
  # half of the ANSI palette is read from.
  illoLightness = {
    "10" = 95.1; "20" = 87.5; "30" = 79.8; "40" = 64.5;
    "50" = 42.8; "60" = 31.2; "70" = 20.0;
  };

  transpose = ramp: step: hex:
    let anchor = ramp.${step}; in
    lib.mapAttrs
      (_: level:
        if level >= anchor
        then mix hex white ((level - anchor) / (100.0 - anchor))
        else mix hex black (1.0 - level / anchor))
      ramp;

  family = transpose lightness;
  illo = transpose illoLightness;

  # Where each color belongs in that ramp. The accent is what a button is
  # painted with, so it goes at 500, where Discord paints its own and where
  # white text is meant to sit on top of it. The others are colors this
  # palette means to be read on a dark panel, so they go at 360, where
  # Discord reads them as text, and the darker step a filled button uses
  # falls out of the ramp below them.
  numbered = {
    inherit primary;
    brand = family "500" accent;
    blue = family "360" accent2;
    red = family "360" error;
    yellow = family "360" warning;
    green = family "360" success;
    teal = family "360" info;
    # Discord's orange is the warm step between its yellow and its red, which
    # is what the palette's own ANSI yellow is beside its bright one.
    orange = family "360" colors.yellow;
  };

  # Discord's own translation from the old numbering to the new one, lifted
  # from the `.visual-refresh` block of its stylesheet: for each step of an
  # old family, the index of the new family's step it became. The old top
  # steps crowd onto one index, so several rows can name the same one.
  refreshed = {
    "blurple" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 4; "230" = 7; "260" = 10; "300" = 15; "330" = 21; "345" = 26;
      "360" = 29; "400" = 38; "430" = 41; "460" = 45; "500" = 50; "530" = 54; "560" = 59; "600" = 65; "630" = 70;
      "660" = 74; "700" = 81; "730" = 82; "760" = 84; "800" = 86; "830" = 91; "860" = 96; "900" = 99;
    };
    "blue-new" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 5; "230" = 11; "260" = 16; "300" = 24; "330" = 30; "345" = 36;
      "360" = 40; "400" = 46; "430" = 52; "460" = 57; "500" = 62; "530" = 67; "560" = 71; "600" = 75; "630" = 78;
      "660" = 81; "700" = 84; "730" = 87; "760" = 90; "800" = 92; "830" = 94; "860" = 95; "900" = 96;
    };
    "red-new" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 1; "230" = 5; "260" = 10; "300" = 16; "330" = 21; "345" = 30;
      "360" = 38; "400" = 46; "430" = 48; "460" = 55; "500" = 62; "530" = 67; "560" = 71; "600" = 75; "630" = 77;
      "660" = 81; "700" = 84; "730" = 89; "760" = 92; "800" = 95; "830" = 96; "860" = 98; "900" = 99;
    };
    "yellow-new" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 6; "230" = 15; "260" = 31; "300" = 36; "330" = 39; "345" = 55;
      "360" = 60; "400" = 63; "430" = 68; "460" = 72; "500" = 76; "530" = 79; "560" = 82; "600" = 84; "630" = 86;
      "660" = 86; "700" = 88; "730" = 90; "760" = 92; "800" = 93; "830" = 96; "860" = 100; "900" = 100;
    };
    "green-new" = {
      "100" = 1; "130" = 1; "160" = 3; "200" = 9; "230" = 16; "260" = 21; "300" = 25; "330" = 29; "345" = 34;
      "360" = 40; "400" = 45; "430" = 52; "460" = 58; "500" = 63; "530" = 69; "560" = 73; "600" = 77; "630" = 80;
      "660" = 83; "700" = 86; "730" = 89; "760" = 91; "800" = 94; "830" = 96; "860" = 98; "900" = 99;
    };
    "teal-new" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 7; "230" = 13; "260" = 19; "300" = 24; "330" = 30; "345" = 33;
      "360" = 38; "400" = 45; "430" = 53; "460" = 59; "500" = 65; "530" = 70; "560" = 74; "600" = 78; "630" = 81;
      "660" = 84; "700" = 86; "730" = 89; "760" = 92; "800" = 94; "830" = 96; "860" = 98; "900" = 99;
    };
    "orange-new" = {
      "100" = 1; "130" = 1; "160" = 1; "200" = 3; "230" = 8; "260" = 14; "300" = 21; "330" = 30; "345" = 35;
      "360" = 39; "400" = 42; "430" = 45; "460" = 57; "500" = 62; "530" = 67; "560" = 73; "600" = 75; "630" = 80;
      "660" = 81; "700" = 82; "730" = 87; "760" = 89; "800" = 92; "830" = 99; "860" = 99; "900" = 100;
    };
  };

  # A family at all hundred steps: the colors it is given at the indices they
  # belong to, every index between two of them mixed from both, and the ends
  # carried on to white and black.
  ramp = anchored:
    let
      points = lib.sort (a: b: a.index < b.index)
        ([{ index = 0; hex = white; }]
          ++ lib.mapAttrsToList (index: hex: { index = lib.toInt index; inherit hex; }) anchored
          ++ [{ index = 101; hex = black; }]);
      step = index:
        let
          low = lib.last (lib.filter (point: point.index <= index) points);
          high = lib.head (lib.filter (point: point.index >= index) points);
        in
        if low.index == high.index then low.hex
        else mix low.hex high.hex ((index - low.index) * 1.0 / (high.index - low.index));
    in
    lib.listToAttrs (map (index: lib.nameValuePair (toString index) (step index)) (lib.range 1 100));

  # An old family put on the new numbering. Where several old steps land on
  # one index the darkest wins, which is the value Discord's own family has
  # there — `listToAttrs` keeps the first of a repeated name, so the steps
  # are walked from black upward.
  expand = correspondence: shades:
    ramp (lib.listToAttrs (map
      (step: lib.nameValuePair (toString correspondence.${step}) shades.${step})
      (lib.sort (a: b: lib.toInt a > lib.toInt b) (lib.attrNames correspondence))));

  # The new neutral family is the same walk of the roles, at the indices the
  # refreshed client reads them: message text at 4 under `--text-default`,
  # the quieter text at 16 and 23, the channel list's names at 28, a slider
  # track and a scrollbar in the forties, a raised surface — modal, embed,
  # message box — at 64, the window at 69, the server bar at 73 and the frame
  # behind it at 78. 1 is what Discord draws on top of a filled button, and
  # 50 is where the old numbering's 500 landed.
  neutral = ramp {
    "1" = mix text white 0.5;
    "4" = text;
    "16" = subtext;
    "23" = muted;
    "28" = mix muted overlay 0.4;
    "50" = overlay;
    "64" = surface;
    "69" = base;
    "73" = mantle;
    "78" = mix mantle black 0.25;
    "100" = black;
  };

  families = numbered // {
    inherit neutral;
    blurple = expand refreshed."blurple" numbered.brand;
    "blue-new" = expand refreshed."blue-new" numbered.blue;
    "red-new" = expand refreshed."red-new" numbered.red;
    "yellow-new" = expand refreshed."yellow-new" numbered.yellow;
    "green-new" = expand refreshed."green-new" numbered.green;
    "teal-new" = expand refreshed."teal-new" numbered.teal;
    "orange-new" = expand refreshed."orange-new" numbered.orange;
    # The pink family has no old one behind it, and its ramp is the blurple's
    # to within a percent, so it borrows that translation. 50 is where
    # Discord reads it as ANSI magenta.
    "pink" = expand refreshed."blurple" (family "500" colors.brightMagenta);
    # The illustration colors, where the bright half of the ANSI palette is
    # read from: bright blue and bright magenta at 30, bright green at 50 and
    # bright yellow at 60.
    "illo-blue" = illo "30" colors.brightBlue;
    "illo-pink" = illo "30" colors.brightMagenta;
    "illo-purple" = illo "30" colors.magenta;
    "illo-green" = illo "50" colors.brightGreen;
    "illo-yellow" = illo "60" colors.brightYellow;
    "illo-orange" = illo "30" colors.yellow;
  };

  # The washes Discord lightens a hovered row or tints a callout with. Each
  # of these is one color at every step, the step naming the alpha rather
  # than a shade — `--opacity-12: hsl(var(--opacity-12-hsl)/0.12)` — so only
  # the triple is written and Discord keeps the alpha it chose.
  washSteps = [
    "1" "4" "8" "12" "16" "20" "24" "28" "32" "36" "40" "44" "48"
    "52" "56" "60" "64" "68" "72" "76" "80" "84" "88" "92" "96"
  ];
  washes = {
    "opacity" = muted;
    "opacity-blurple" = accent;
    "opacity-blue" = accent2;
    "opacity-red" = error;
    "opacity-yellow" = warning;
    "opacity-green" = success;
    "opacity-teal" = info;
    "opacity-orange" = colors.yellow;
    "opacity-pink" = colors.brightMagenta;
  };

  # The triple Discord builds its translucent washes from: the color rounded
  # to the whole degrees and percents that format is written in.
  # `--saturation-factor` is Discord's own saturation slider, kept working
  # rather than flattened.
  triple = name: hex:
    let color = hsl hex; in
    "  --${name}-hsl: ${toString color.h} calc(var(--saturation-factor, 1) * ${toString color.s}%) ${toString color.l}%;\n";

  # Each step twice: the hex, which is exact, and the triple.
  declare = name: step: hex:
    "  --${name}-${step}: ${hex};\n" + triple "${name}-${step}" hex;

  declarations = lib.concatStrings (lib.mapAttrsToList
    (name: shades: lib.concatStrings (lib.mapAttrsToList (declare name) shades))
    families);

  washDeclarations = lib.concatStrings (lib.mapAttrsToList
    (name: hex: lib.concatMapStrings (step: triple "${name}-${step}" hex) washSteps)
    washes);

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
   * @version 2.0.0
   */

  /* Edits here are replaced at the next Home Manager activation. */

'' + ":root:root {\n" + declarations + washDeclarations + variables + "}\n"
