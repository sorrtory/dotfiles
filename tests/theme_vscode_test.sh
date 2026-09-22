#!/usr/bin/env bash
# VS Code's side of the theme: one local extension contributing a theme called
# "Dotfiles" for every palette, built from the native extension a palette names
# or drawn from the palette when it names none, with overrides reaching it
# without touching the operator's settings file.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v jq >/dev/null || fail 'jq must be on PATH'

# The built Dotfiles extension for a theme, optionally with extra modules.
extension() {
  nix build --impure --no-link --print-out-paths --expr "
    let cfg = (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
      modules = [ ({ lib, ... }: { dotfiles.theme.name = lib.mkForce \"$1\"; }) ${2-} ];
    };
    in builtins.head (builtins.filter (e: (e.vscodeExtUniqueId or \"\") == \"dotfiles.dotfiles-theme\")
      cfg.config.programs.vscode.profiles.default.extensions)" 2>/dev/null ||
    fail "Dotfiles extension for $1"
}

theme_json() {
  echo "$1/share/vscode/extensions/dotfiles.dotfiles-theme/themes/dotfiles-color-theme.json"
}

# The repository's settings name the generated theme, permanently, and stay a
# live-editable symlink so the VS Code UI can still write to them.
grep -qF '"workbench.colorTheme": "Dotfiles"' "$REPO_ROOT/configs/vscode/settings.json" ||
  fail 'settings.json does not select the generated theme'
# mkOutOfStoreSymlink makes the store path itself a link to the repository
# file, so what activation installs is a link the editor can write through.
settings_source=$(nix eval --impure --raw --expr "
  ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.config.xdg.configFile.\"Code/User/settings.json\".source)" \
  2>/dev/null) || fail 'settings.json has no source'
[[ $(readlink "$settings_source") == "$REPO_ROOT/configs/vscode/settings.json" ]] ||
  fail "settings.json is not an out-of-store symlink, so the UI could not save it: $settings_source"

# Every extension the editor is given, by the id Home Manager links it under.
mapfile -t ids < <(nix eval --impure --json --expr "
  map (e: e.vscodeExtUniqueId or \"?\")
    (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.config.programs.vscode.profiles.default.extensions" \
  2>/dev/null | jq -r '.[]')
for want in dotfiles.dotfiles-theme jdinhlife.gruvbox zhuangtongfa.material-theme; do
  printf '%s\n' "${ids[@]}" | grep -qx "$want" ||
    fail "extensions do not include $want: ${ids[*]}"
done

# Each palette's expected editor background: the native theme's own for the
# two that name one, the palette's base for the one that does not.
declare -A want_background=(
  [gruvbox]='#1d2021'
  [onedark]='#282c34'
  [autumn-leaves]='#291b17'
)

for theme in gruvbox onedark autumn-leaves; do
  ext=$(extension "$theme")
  manifest="$ext/share/vscode/extensions/dotfiles.dotfiles-theme/package.json"
  json=$(theme_json "$ext")

  # One theme, under the name the repository's settings select.
  [[ $(jq -r '.contributes.themes | length' "$manifest") == 1 ]] ||
    fail "$theme: the extension contributes more than one theme"
  [[ $(jq -r '.contributes.themes[0].label' "$manifest") == Dotfiles ]] ||
    fail "$theme: the contributed theme is not called Dotfiles"
  [[ $(jq -r '.contributes.themes[0].uiTheme' "$manifest") == vs-dark ]] ||
    fail "$theme: the contributed theme is not a dark one"

  jq -e . "$json" >/dev/null || fail "$theme: the theme file is not valid JSON"
  [[ $(jq -r '.name' "$json") == Dotfiles ]] ||
    fail "$theme: the theme kept the name it was built from"
  [[ $(jq -r '.type' "$json") == dark ]] || fail "$theme: the theme is not dark"
  [[ $(jq -r '.colors["editor.background"]' "$json") == "${want_background[$theme]}" ]] ||
    fail "$theme: editor.background is $(jq -r '.colors["editor.background"]' "$json"), expected ${want_background[$theme]}"
  [[ $(jq -r '.tokenColors | length' "$json") -gt 20 ]] ||
    fail "$theme: the theme colors almost no syntax"
done

# An operator override reaches the editor through the theme the extension
# contributes, so nothing has to rewrite settings.json to carry it. A native
# theme is the harder case: the override has to win over the value the
# upstream extension shipped.
override='{ dotfiles.theme.overrides.vscode.colorCustomizations = { "editor.background" = "#123456"; }; }'
json=$(theme_json "$(extension gruvbox "$override")")
[[ $(jq -r '.colors["editor.background"]' "$json") == '#123456' ]] ||
  fail 'an override does not reach the theme built from a native extension'

json=$(theme_json "$(extension autumn-leaves "$override")")
[[ $(jq -r '.colors["editor.background"]' "$json") == '#123456' ]] ||
  fail 'an override does not reach the generated theme'

# A role remap follows the theme, the same as it does for every other app.
remap='{ dotfiles.theme.overrides.vscode = r: { base = r.mantle; }; }'
json=$(theme_json "$(extension autumn-leaves "$remap")")
[[ $(jq -r '.colors["editor.background"]' "$json") == '#1f1311' ]] ||
  fail 'a role remap does not reach the generated theme'

printf 'theme VS Code tests passed\n'
