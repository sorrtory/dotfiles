{ lib }:

# The palette's roles as custom properties in userContent.css. The page rules
# installed in Stylus use these colors without carrying a second palette.
# Each role becomes `--dotfiles-<role>` on every page's root. The prefix keeps
# them clear of a site's own variables; a page can read them, as it can
# already tell its background was cleared.

colors:
let
  roles = [
    "base" "mantle" "surface" "overlay"
    "text" "subtext" "muted"
    "accent" "accent2"
    "error" "warning" "success" "info"
  ];
in
''
  /* Generated from the dotfiles.theme palette by modules/theme/firefox-content.nix. */
  :root {
  ${lib.concatMapStrings (role: "  --dotfiles-${role}: ${colors.${role}} !important;\n") roles}}

''
