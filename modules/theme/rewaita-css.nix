{ lib }:

# A Rewaita user palette from a resolved theme. Rewaita reads these CSS
# variables, hands them to its GTK 3, GTK 4 and GNOME Shell templates, and
# picks the accent out of the numbered color families by the name GNOME's
# accent setting carries. Its own palettes are the format this follows; see
# `src/themes/dark/` in the Rewaita source.

let
  # Shades a palette does not name.
  inherit (import ./color.nix { inherit lib; }) mix;

  # Five steps from a color toward the theme's background: what Rewaita's own
  # palettes fill the -2 … -5 shades with, by hand, in no stated system.
  family = base: color: lib.listToAttrs (lib.imap0
    (index: ratio: lib.nameValuePair (toString (index + 1)) (mix color base ratio))
    [ 0.0 0.2 0.4 0.6 0.8 ]);
in
{ colors, gnomeAccent ? null }:
let
  # Each family's first shade is where GNOME's accent lands when its name is
  # chosen: "blue" takes blue-1, "teal" blue-2, "slate" dark-1, and so on
  # (Rewaita's accent map in src/utils.py).
  families = {
    blue = family colors.base colors.brightBlue;
    green = family colors.base colors.brightGreen;
    yellow = family colors.base colors.brightYellow;
    orange = family colors.base colors.accent;
    red = family colors.base colors.brightRed;
    purple = family colors.base colors.brightMagenta;
  } // {
    # Neutrals: borders and disabled text, then text, then surfaces.
    brown = family colors.muted colors.overlay;
    light = family colors.overlay colors.text;
    dark = {
      "1" = colors.overlay;
      "2" = colors.surface;
      "3" = colors.base;
      "4" = colors.mantle;
      "5" = mix colors.base colors.mantle 0.5;
    };
  };

  # Which shade each GNOME accent name picks, from Rewaita's accent map.
  accentSlot = {
    blue = [ "blue" "1" ];
    teal = [ "blue" "2" ];
    green = [ "green" "1" ];
    yellow = [ "yellow" "1" ];
    orange = [ "orange" "1" ];
    red = [ "red" "1" ];
    pink = [ "purple" "1" ];
    purple = [ "purple" "2" ];
    slate = [ "dark" "1" ];
  };

  # Teal and purple are a family's second shade rather than a step of the
  # ramp, and the shade GNOME's accent will land on becomes the theme's own
  # accent, so the desktop highlights in the color the palette declares.
  named = lib.recursiveUpdate
    (lib.recursiveUpdate families {
      blue."2" = colors.brightCyan;
      purple."2" = colors.magenta;
    })
    (lib.optionalAttrs (gnomeAccent != null)
      (lib.setAttrByPath
        (accentSlot.${gnomeAccent} or (throw "modules/theme: GNOME has no accent named \"${gnomeAccent}\""))
        colors.accent));

  variables = {
    window-bg-color = colors.base;
    window-fg-color = colors.text;

    view-bg-color = colors.base;
    view-fg-color = colors.text;

    headerbar-bg-color = colors.mantle;
    headerbar-backdrop-color = colors.mantle;
    headerbar-fg-color = colors.text;

    popover-bg-color = colors.base;
    popover-fg-color = colors.text;
    dialog-bg-color = colors.base;
    dialog-fg-color = colors.text;

    card-bg-color = colors.surface;
    card-fg-color = colors.text;

    sidebar-bg-color = colors.base;
    sidebar-fg-color = colors.text;
    sidebar-backdrop-color = colors.base;
    sidebar-border-color = colors.overlay;
    secondary-sidebar-bg-color = colors.base;
    secondary-sidebar-fg-color = colors.text;
    secondary-sidebar-backdrop-color = colors.base;
    secondary-sidebar-border-color = colors.overlay;

    active-toggle-bg-color = colors.text;
    active-toggle-fg-color = colors.base;
  } // lib.concatMapAttrs
    (name: shades: lib.mapAttrs' (shade: value: lib.nameValuePair "${name}-${shade}" value) shades)
    named;
in
''
  /* Generated from the theme in home.nix; see modules/theme. Edits here are
     replaced at the next Home Manager activation. */
  :root {
  ${lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") variables)}}

  toast {
    background-color: var(--window-bg-color);
    color: var(--window-fg-color);
  }

  .inline {
    background-color: rgba(0, 0, 0, 0);
  }
''
