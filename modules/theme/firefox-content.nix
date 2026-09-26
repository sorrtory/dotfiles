{ lib }:

# The palette's roles as custom properties, prepended to userContent.css so a
# site's rules there can name a theme color instead of a fixed one. Each role
# becomes `--dotfiles-<role>` on every page's root. The prefix keeps them clear
# of any site's own variables; a page can read them, as it can already tell
# its background was cleared.

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
