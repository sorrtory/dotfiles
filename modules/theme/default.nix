{ config, lib, pkgs, ... }:

# One palette drives every themed app. A palette exports semantic roles and
# the 16 ANSI colors; each app sees them with the theme's override for that
# app layered on top, then the operator's. Apps take their colors from
# `dotfiles.theme.forApp "<app>"` and register in `dotfiles.theme.apps` so
# the notice printed after a switch can say how each one picks it up.
# docs/DECISIONS.md records the palette and application ownership decisions.

let
  inherit (lib) mkOption types;

  cfg = config.dotfiles.theme;

  requiredRoles = [
    "base" "mantle" "surface" "overlay"
    "text" "subtext" "muted"
    "accent" "accent2"
    "error" "warning" "success" "info"
  ];
  requiredAnsi = lib.concatMap (color: [ color "bright${lib.toUpper (lib.substring 0 1 color)}${lib.substring 1 (-1) color}" ]) [
    "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white"
  ];

  # Alphas for translucent surfaces. Off makes every app opaque, whatever an
  # override asks for.
  alphaOn = { window = 0.9; surface = 0.9; popup = 0.9; };
  alphaOff = lib.mapAttrs (_: _: 1.0) alphaOn;

  isHex = value: builtins.isString value && builtins.match "#[0-9a-fA-F]{6}" value != null;

  # The theme's roles and ANSI colors, flattened, after checking the palette
  # exports all of them.
  checked = name: palette:
    let
      roles = palette.roles or { };
      ansi = palette.ansi or { };
      missing = lib.filter (role: !(roles ? ${role})) requiredRoles
        ++ lib.filter (color: !(ansi ? ${color})) requiredAnsi;
      malformed = lib.filter (key: !(isHex (roles // ansi).${key}))
        (requiredRoles ++ requiredAnsi);
    in
    if missing != [ ] then
      throw "dotfiles.theme: palette \"${name}\" is missing required role ${lib.concatMapStringsSep ", " (role: "\"${role}\"") missing}"
    else if malformed != [ ] then
      throw "dotfiles.theme: palette \"${name}\" has a role that is not a #rrggbb hex: ${lib.concatStringsSep ", " malformed}"
    else
      roles // ansi;

  paletteOf = name:
    cfg.palettes.${name} or (throw "dotfiles.theme: no palette named \"${name}\"; known: ${lib.concatStringsSep ", " (lib.attrNames cfg.palettes)}");

  globalIn = name: checked name (paletteOf name) // {
    alpha = if cfg.transparency then alphaOn else alphaOff;
  };

  # Keys an app takes besides the roles, the ANSI colors and `alpha`: its own
  # escape hatch, where an override carries that app's native key names
  # instead of a role. The table is here rather than in `dotfiles.theme.apps`
  # because a module registers itself there in the same evaluation that calls
  # `forApp`, and reading one from the other would tie the two together.
  extraKeys = {
    neovim = [ "highlights" ];
    obsidian = [ "variables" ];
    spotify = [ "scheme" ];
    vesktop = [ "variables" ];
    vscode = [ "colorCustomizations" ];
  };

  isAlpha = value:
    (builtins.isFloat value || builtins.isInt value) && value >= 0 && value <= 1;

  # An override is checked the way a palette is, so a misspelled role or a hex
  # missing its `#` is an evaluation error rather than a line that silently
  # does nothing. `source` says which layer wrote it.
  checkedOverride = source: app: produced:
    let
      colorKeys = requiredRoles ++ requiredAnsi;
      own = extraKeys.${app} or [ ];
      known = colorKeys ++ [ "alpha" ] ++ own;
      given = lib.attrNames produced;
      unknown = lib.filter (key: !(lib.elem key known)) given;
      badColor = lib.filter (key: !(isHex produced.${key}))
        (lib.filter (key: lib.elem key colorKeys) given);
      alphaGiven = produced.alpha or { };
      badAlpha = lib.filter (key: !(lib.elem key (lib.attrNames alphaOn)) || !(isAlpha alphaGiven.${key}))
        (lib.attrNames alphaGiven);
      where = "${source} override for \"${app}\"";
      names = keys: lib.concatMapStringsSep ", " (key: "\"${key}\"") keys;
      plural = if lib.length unknown == 1 then "is not a key" else "are not keys";
      ownLine = if own == [ ] then "\"${app}\" has no keys of its own." else "\"${app}\"'s own keys: ${names own}";
    in
    if !(builtins.isAttrs produced) then
      throw "dotfiles.theme: ${where} is not an attrset of colors"
    else if unknown != [ ] then
      throw (
        "dotfiles.theme: ${where} sets ${names unknown}, which ${plural} this theme has.\n"
        + "  Roles: ${names requiredRoles}\n"
        + "  ANSI: ${names requiredAnsi}\n"
        + "  Transparency: \"alpha\"\n"
        + "  ${ownLine}")
    else if badColor != [ ] then
      throw "dotfiles.theme: ${where} sets ${names badColor} to something that is not a #rrggbb hex"
    else if produced ? alpha && !(builtins.isAttrs alphaGiven) then
      throw "dotfiles.theme: ${where} sets \"alpha\" to something that is not a table of ${names (lib.attrNames alphaOn)}"
    else if badAlpha != [ ] then
      throw "dotfiles.theme: ${where} sets alpha ${names badAlpha}; an alpha is ${names (lib.attrNames alphaOn)} with a number from 0.0 to 1.0"
    else
      produced;

  # An override is an attrset of hexes, or a function of the colors so far
  # (`r: { base = r.mantle; }`), which is what lets a remap follow the theme.
  applyOverride = app: colors: { source, override }:
    lib.recursiveUpdate colors
      (checkedOverride source app
        (if lib.isFunction override then override colors else override));

  forAppIn = name: app:
    let
      resolved = lib.foldl (applyOverride app) (globalIn name) [
        { source = "palette \"${name}\""; override = (paletteOf name).overrides.${app} or { }; }
        { source = "the operator's"; override = cfg.overrides.${app} or { }; }
      ];
    in
    if cfg.transparency then resolved else resolved // { alpha = alphaOff; };

  forApp = forAppIn cfg.name;

  overrideType = types.either (types.functionTo types.attrs) types.attrs;

  liveFileTargets = lib.mapAttrsToList (target: source: { inherit target source; }) cfg.liveFiles;

  stateFile = "${config.xdg.stateHome}/dotfiles/theme";
  # The digest makes an edit to a palette count as a change too, so a switch
  # is not the only thing that reaches an app.
  stateValue = "${cfg.name} transparency=${lib.boolToString cfg.transparency} colors=${
    lib.substring 0 12 (builtins.hashString "sha256"
      (builtins.toJSON (lib.mapAttrs (app: _: forApp app) cfg.apps)))
  }";
in
{
  # Telegram's theme needs an activation step and a package, so it is a
  # module of its own rather than one more translator function.
  imports = [ ./telegram.nix ./vesktop.nix ];

  options.dotfiles.theme = {
    name = mkOption {
      type = types.str;
      default = "gruvbox";
      example = "autumn-leaves";
      description = "The palette every themed app follows: a name from `dotfiles.theme.palettes`.";
    };

    transparency = mkOption {
      type = types.bool;
      default = true;
      description = "Whether themed apps draw translucent windows and surfaces.";
    };

    overrides = mkOption {
      type = types.attrsOf overrideType;
      default = { };
      example = lib.literalExpression ''
        {
          wezterm = r: { base = r.mantle; };
          sublime-text = { accent = "#d65d0e"; alpha.window = 0.95; };
        }
      '';
      description = ''
        The operator's per-app overrides, applied after the theme's own. Each
        is an attrset of colors or a function of the colors so far; `alpha`
        overrides the transparency table and only applies while transparency
        is on.

        The app name must be one that registers in `dotfiles.theme.apps`, and
        a key must be a role, an ANSI color, `alpha`, or one of that app's own
        keys — `highlights` for Neovim, `colorCustomizations` for VS Code,
        `scheme` for Spotify, `variables` for Obsidian and Vesktop. Anything
        else is an evaluation error rather than a line that does nothing.

        What it cannot check is whether the app's translator reads the role at
        all: `modules/theme/<app>-*.nix` writes one app's format out of the
        roles it needs, and a role that format has no slot for is dropped
        there in silence. Overriding `info` for `gnome` is the worked example
        — `rewaita-css.nix` never asks for it.
      '';
    };

    palettes = mkOption {
      type = types.attrsOf types.attrs;
      default = {
        gruvbox = import ./palettes/gruvbox.nix;
        autumn-leaves = import ./palettes/autumn-leaves.nix;
        onedark = import ./palettes/onedark.nix;
      };
      description = ''
        Every theme there is. A palette has `roles` and `ansi`, and may add
        `overrides.<app>` for how that theme should differ in one app.
      '';
    };

    forApp = mkOption {
      type = types.functionTo types.attrs;
      readOnly = true;
      default = forApp;
      description = "The current theme's colors and alphas as the given app should use them.";
    };

    forAppIn = mkOption {
      type = types.functionTo (types.functionTo types.attrs);
      readOnly = true;
      default = forAppIn;
      description = ''
        `forApp` for a named theme rather than the current one, for an app that
        generates a file per theme instead of one that follows the switch.
      '';
    };

    assetsIn = mkOption {
      type = types.functionTo types.attrs;
      readOnly = true;
      default = name: (paletteOf name).assets or { };
      description = ''
        A theme's non-color assets, every one optional: `gnomeAccent`,
        `iconTheme` and `wallpaper`, which overrides the wallpaper directory's
        `<theme>.jpg`. An app falls back when the theme declares none.
      '';
    };

    assets = mkOption {
      type = types.attrs;
      readOnly = true;
      default = (paletteOf cfg.name).assets or { };
      description = "The current theme's non-color assets.";
    };

    wallpaperDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/Pictures/wallpapers";
      description = ''
        Where a theme's wallpaper is looked for, by the name of the theme:
        `<wallpaperDir>/<theme>.jpg`. The pictures live in the home directory
        rather than the repository, so they can be swapped without a rebuild
        and stay out of git; a theme that names a `wallpaper` asset overrides
        the convention. Activation says so when the file is missing.
      '';
    };

    wallpaperFor = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      default = name: (paletteOf name).assets.wallpaper or "${cfg.wallpaperDir}/${name}.jpg";
      description = "Where the given theme's wallpaper is.";
    };

    wallpaper = mkOption {
      type = types.str;
      readOnly = true;
      default = cfg.wallpaperFor cfg.name;
      description = "Where the current theme's wallpaper is.";
    };

    dataDir = mkOption {
      type = types.str;
      readOnly = true;
      default = "${config.xdg.dataHome}/dotfiles/theme";
      description = "Where an app with nowhere of its own keeps its generated theme.";
    };

    liveFiles = mkOption {
      type = types.attrsOf types.path;
      example = lib.literalExpression ''
        { "''${config.xdg.dataHome}/dotfiles/theme/wezterm.lua" = generated; }
      '';
      default = { };
      description = ''
        Generated files, by absolute path, that activation copies into place
        as ordinary files, written over in place when they change. An app
        watching such a file sees an edit, which a Home Manager symlink
        swapped to a new store path does not give it.
      '';
    };

    apps = mkOption {
      default = { };
      description = "How each themed app takes a switch, for the notice activation prints.";
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          label = mkOption {
            type = types.str;
            default = name;
            description = "The app's name in the notice.";
          };
          apply = mkOption {
            type = types.enum [ "live" "restart" "relogin" ];
            description = ''
              How the app picks up a switch. An activation step can move an
              app at run time with `dotfilesThemeApply[<app>]=<value>`, as
              GNOME does when it cannot recolor the running session.
            '';
          };
          restartNote = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "Reload Window";
            description = "What restarting means for this app, when not the obvious.";
          };
          setup = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "A one-time step the operator does by hand so later switches reach the app.";
          };
          check = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Shell run when the notice is printed; each line it prints is listed as needing attention.";
          };
        };
      }));
    };
  };

  config = {
    # An override for an app nothing themes is a line that does nothing, so it
    # is an error rather than a surprise. Checked here rather than in
    # `forApp`, which an app calls while registering itself in `apps`; an
    # assertion reads the finished set once, after every module has had its
    # say. Every palette is checked, not just the selected one, so a typo in
    # a theme is caught before that theme is switched to.
    assertions =
      let
        themed = lib.attrNames cfg.apps;
        strayIn = source: overrides:
          map
            (app: "${source} has an override for \"${app}\", which is not a themed app. Themed apps: ${lib.concatStringsSep ", " themed}.")
            (lib.filter (app: !(lib.elem app themed)) (lib.attrNames overrides));
        stray = strayIn "dotfiles.theme.overrides" cfg.overrides
          ++ lib.concatLists (lib.mapAttrsToList
            (name: palette: strayIn "palette \"${name}\"" (palette.overrides or { }))
            cfg.palettes);
      in
      [{
        assertion = stray == [ ];
        message = "dotfiles.theme: " + lib.concatStringsSep "\n  " stray;
      }];

    # Before anything that applies a theme, so those steps can move an app.
    home.activation.dotfilesThemeInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      declare -gA dotfilesThemeApply=(
        ${lib.concatStrings (lib.mapAttrsToList (name: app: "[${lib.escapeShellArg name}]=${app.apply} ") cfg.apps)}
      )
      # Whether this activation changes the theme, for the steps that apply it
      # to one app and for the notice at the end.
      if [[ "$(cat ${lib.escapeShellArg stateFile} 2>/dev/null)" == ${lib.escapeShellArg stateValue} ]]; then
        dotfilesThemeChanged=0
      else
        dotfilesThemeChanged=1
      fi
    '';

    home.activation.dotfilesThemeFiles = lib.hm.dag.entryAfter [ "dotfilesThemeInit" ] (
      lib.concatMapStrings ({ target, source }: ''
        run mkdir -p ${lib.escapeShellArg (dirOf target)}
        if [[ -L ${lib.escapeShellArg target} ]]; then
          run rm -f ${lib.escapeShellArg target}
        fi
        if ! cmp -s ${source} ${lib.escapeShellArg target}; then
          # cp onto an existing file truncates and rewrites that same file,
          # which is the change a watcher is waiting for.
          run cp --no-preserve=mode ${source} ${lib.escapeShellArg target}
        fi
      '') liveFileTargets
    );

    # After every other step, so it ends the output and steps that apply the
    # theme have moved any app whose live apply failed. Printed only when the
    # theme or transparency differs from the previous activation.
    home.activation.dotfilesThemeHint = lib.hm.dag.entryAfter
      (lib.attrNames (removeAttrs config.home.activation [ "dotfilesThemeHint" ])) ''
      if (( dotfilesThemeChanged )); then
        dotfilesThemeList() {
          local apply=$1 heading=$2 name line=
          for name in $(printf '%s\n' "''${!dotfilesThemeLabel[@]}" | sort); do
            if [[ ''${dotfilesThemeApply[$name]} == "$apply" ]]; then
              line+="''${line:+, }''${dotfilesThemeLabel[$name]}"
            fi
          done
          [[ -z $line ]] || echo "  $heading: $line"
        }
        declare -gA dotfilesThemeLabel=(
          ${lib.concatStrings (lib.mapAttrsToList (name: app:
            "[${lib.escapeShellArg name}]=${lib.escapeShellArg (app.label + lib.optionalString (app.restartNote != null) " (${app.restartNote})")} ") cfg.apps)}
        )
        echo
        echo ${lib.escapeShellArg "Theme is now ${cfg.name}, transparency ${if cfg.transparency then "on" else "off"}."}
        dotfilesThemeList live "Updated live"
        dotfilesThemeList restart "Restart to apply"
        dotfilesThemeList relogin "Log out and back in"
        ${lib.concatStrings (lib.mapAttrsToList (name: app: lib.optionalString (app.setup != null) ''
          echo ${lib.escapeShellArg "  Once, if not done yet — ${app.label}: ${app.setup}"}
        '') cfg.apps)}
        ${lib.concatStrings (lib.mapAttrsToList (name: app: lib.optionalString (app.check != null) ''
          while IFS= read -r line; do
            [[ -n $line ]] && echo ${lib.escapeShellArg "  Needs attention — ${app.label}:"} "$line"
          done < <(${pkgs.writeShellScript "theme-check-${name}" app.check})
        '') cfg.apps)}
        echo
        run mkdir -p ${lib.escapeShellArg (dirOf stateFile)}
        run cp --no-preserve=mode ${pkgs.writeText "theme-state" stateValue} ${lib.escapeShellArg stateFile}
      fi
    '';
  };
}
