{ lib }:

# An Obsidian theme from a resolved theme. Obsidian's look is a set of CSS
# variables on `.theme-dark`, so this is that set, filled from the palette.
#
# Solid colors only, and the transparency switch does not reach here: the
# window can be see-through on Linux, but Chromium redraws it with glitches on
# GNOME Wayland while the window moves, and a wallpaper behind the panels was
# too busy for writing. That was decided for the hand-made Autumn Glass theme
# this replaced and has not changed.
#
# Obsidian's chrome sits a shade *above* the editor rather than below it — the
# ribbon, tab bar and status bar are lighter than the note — which is the one
# place this reads the roles differently from every other app, and is how the
# hand-made theme was drawn.

colors:
let
  inherit (import ./color.nix { inherit lib; }) mix rgba hsl;
  inherit (colors) base mantle surface overlay text subtext muted accent accent2 error warning success info;

  # Shades between two roles, each named for what it is rather than repeated
  # at every use.
  chrome = mix base surface 0.5;          # ribbon, tabs, title and status bar
  raised = mix base surface 0.6;          # modals, menus and callouts
  sunken = mix mantle base 0.4;           # code blocks
  border = mix surface overlay 0.5;
  borderHover = mix overlay muted 0.3;
  field = mix surface overlay 0.35;       # an input at rest
  shadow = mix mantle "#000000" 0.5;

  # The accent ramp. Obsidian hovers a control by walking toward the second
  # accent, and a heading or a link one step further toward the text.
  accentHover = mix accent accent2 0.35;
  accentStrong = mix accent accent2 0.5;
  accentLight = mix accent2 "#ffffff" 0.15;
  accentLighter = mix accent2 "#ffffff" 0.2;
  onAccent = mix text "#ffffff" 0.5;
  errorLight = mix error "#ffffff" 0.15;
  # Parchment warmer than the plain text: a tag, and the scrollbar thumb,
  # which is a step back toward the accent because it is drawn at low alpha
  # over a dark panel and would otherwise read as white.
  warm = mix accent2 text 0.75;
  warmDim = mix accent2 text 0.6;

  # Match the four Markdown heading shades in the generated Neovim, VS Code
  # and Sublime themes. Deeper levels recede into the muted prose color.
  heading = [
    (mix error base 0.14)
    (mix accent text 0.10)
    (mix accent2 base 0.06)
    (mix info text 0.06)
  ];

  hue = hsl accent;

  variables = {
    # Obsidian derives its own ramp from the accent given as three numbers.
    accent-h = toString hue.h;
    accent-s = "${toString hue.s}%";
    accent-l = "${toString hue.l}%";

    # The note sits a shade deeper than the panels around it.
    background-primary = base;
    background-primary-alt = chrome;
    background-secondary = chrome;
    background-secondary-alt = surface;
    background-modifier-hover = overlay;
    background-modifier-active-hover = mix overlay accent 0.25;
    background-modifier-border = border;
    background-modifier-border-hover = borderHover;
    background-modifier-border-focus = accentStrong;
    background-modifier-form-field = surface;
    background-modifier-message = raised;
    background-modifier-error = error;
    background-modifier-success = success;
    background-modifier-cover = rgba shadow "0.65";
    divider-color = border;

    titlebar-background = chrome;
    titlebar-background-focused = chrome;
    tab-container-background = chrome;
    ribbon-background = chrome;
    ribbon-background-collapsed = base;
    status-bar-background = chrome;

    text-normal = text;
    text-muted = subtext;
    text-faint = muted;
    text-on-accent = onAccent;
    text-accent = accent2;
    text-accent-hover = accentLighter;
    text-error = errorLight;
    text-success = success;
    text-warning = warning;
    text-selection = rgba accent "0.4";
    text-highlight-bg = rgba accent2 "0.3";

    interactive-normal = field;
    interactive-hover = overlay;
    interactive-accent = accent;
    interactive-accent-hover = accentHover;

    nav-item-background-active = rgba accent "0.35";
    nav-item-color-active = onAccent;

    link-color = accent2;
    link-color-hover = accentLighter;
    link-external-color = success;
    link-external-color-hover = mix success "#ffffff" 0.25;
    link-unresolved-color = mix subtext text 0.2;

    h1-color = builtins.elemAt heading 0;
    h2-color = builtins.elemAt heading 1;
    h3-color = builtins.elemAt heading 2;
    h4-color = builtins.elemAt heading 3;
    h5-color = muted;
    h6-color = muted;

    blockquote-border-color = accentHover;
    blockquote-background-color = raised;
    hr-color = overlay;

    # Obsidian's code colors are a short ramp rather than a syntax theme, so
    # they take the same reading of the roles the editors use: comments are
    # muted, strings succeed, and the accents carry keywords and functions.
    code-background = sunken;
    code-normal = mix text subtext 0.25;
    code-comment = muted;
    code-keyword = accentStrong;
    code-function = accent2;
    code-string = success;
    code-value = info;
    code-property = accentLight;
    code-tag = errorLight;
    code-operator = mix subtext text 0.35;
    code-punctuation = subtext;
    code-important = errorLight;

    checkbox-color = accent;
    checkbox-color-hover = accentHover;
    checkbox-border-color = mix muted subtext 0.6;
    checklist-done-color = muted;

    tag-color = warm;
    tag-background = rgba accent "0.25";
    tag-background-hover = rgba accent "0.38";

    modal-background = raised;
    modal-border-color = borderHover;
    prompt-border-color = borderHover;
    menu-background = raised;
    menu-border-color = overlay;

    scrollbar-bg = "transparent";
    scrollbar-thumb-bg = rgba warmDim "0.22";
    scrollbar-active-thumb-bg = rgba warm "0.4";
  } // (colors.variables or { });
in
''
  /* Generated from the theme in home.nix; see modules/theme. Edits here are
     replaced at the next Home Manager activation. */

  .theme-dark {
  ${lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") variables)}}
''
