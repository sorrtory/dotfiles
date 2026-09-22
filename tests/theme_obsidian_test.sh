#!/usr/bin/env bash
# Obsidian's side of the theme: a theme generated per palette at one fixed
# path, named so a vault is linked to it once, setting everything the
# hand-made Autumn Glass theme it replaced did, and a hint that names a vault
# missing the link.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

# The generated stylesheet and manifest for a theme.
files() {
  nix build --impure --no-link --print-out-paths --expr "
    let cfg = ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
          modules = [ ({ lib, ... }: { dotfiles.theme.name = lib.mkForce \"$1\"; }) ];
        }).config;
        dir = cfg.dotfiles.theme.dataDir + \"/obsidian\";
    in [ cfg.home.file.\"\${dir}/theme.css\".source
         cfg.home.file.\"\${dir}/manifest.json\".source ]" 2>/dev/null ||
    fail "Obsidian theme for $1"
}

# nix build prints the paths sorted by store hash, not in the order they were
# asked for, so each one is picked out by its name.
stylesheet() { printf '%s\n' "$@" | grep '\.css$'; }
manifest() { printf '%s\n' "$@" | grep '\.json$'; }

# The manifest names the theme, and the directory a vault links to has to
# carry that same name for Obsidian to find it.
mapfile -t built < <(files gruvbox)
[[ $(jq -r '.name' "$(manifest "${built[@]}")") == Dotfiles ]] ||
  fail 'the manifest does not name the theme Dotfiles'

# The hand-made theme is gone; the generated one is what a vault links to.
[[ ! -e "$REPO_ROOT/configs/obsidian" ]] ||
  fail 'the hand-made Obsidian theme is still in the repository'

# Every variable the hand-made theme set is still set, so no part of the
# window falls back to Obsidian's own dark colors.
wanted=$(git -C "$REPO_ROOT" show 6f3e418^:configs/obsidian/autumn-glass/theme.css 2>/dev/null |
  grep -oP '^\s*--\K[a-z0-9-]+' | sort -u)
[[ -n $wanted ]] || fail 'cannot read the hand-made theme from git to compare against'

for theme in gruvbox autumn-leaves onedark; do
  mapfile -t built < <(files "$theme")
  css=$(stylesheet "${built[@]}")
  grep -q '^\.theme-dark {' "$css" || fail "$theme: the stylesheet does not scope to .theme-dark"
  got=$(grep -oP '^\s*--\K[a-z0-9-]+' "$css" | sort -u)
  missing=$(comm -23 <(printf '%s\n' "$wanted") <(printf '%s\n' "$got"))
  [[ -z $missing ]] || fail "$theme: variables left unset: $(tr '\n' ' ' <<<"$missing")"

  # Every color is a literal Obsidian can use, never an unresolved mix.
  while IFS= read -r value; do
    [[ $value =~ ^(#[0-9a-f]{6}|rgba\([0-9]+,\ [0-9]+,\ [0-9]+,\ 0\.[0-9]+\)|transparent|[0-9]+|[0-9]+%)$ ]] ||
      fail "$theme: \"$value\" is not a color Obsidian can read"
  done < <(grep -oP '^\s*--[a-z0-9-]+:\s*\K[^;]+' "$css")
done

# The hint names a vault that has no link yet, and goes quiet once it has one.
check=$(nix build --impure --no-link --print-out-paths --expr "
  ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.pkgs.writeShellScript \"check\"
    (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.config.dotfiles.theme.apps.obsidian.check)" 2>/dev/null) ||
  fail 'Obsidian registers no check for the hint'

vault="$TEST_ROOT/home/Documents/Knowledge-Database"
mkdir -p "$vault/.obsidian"
HOME="$TEST_ROOT/home" "$check" | grep -q "ln -sfn .*/dotfiles/theme/obsidian $vault/.obsidian/themes/Dotfiles" ||
  fail 'the hint does not give the link command for a vault that is missing it'

mkdir -p "$vault/.obsidian/themes"
ln -s "$TEST_ROOT" "$vault/.obsidian/themes/Dotfiles"
[[ -z $(HOME="$TEST_ROOT/home" "$check") ]] ||
  fail 'the hint still complains about a vault that has the link'

# A directory that is not a vault is not reported: the check looks for the
# .obsidian Obsidian itself creates.
rm -rf "$vault/.obsidian"
[[ -z $(HOME="$TEST_ROOT/home" "$check") ]] ||
  fail 'the hint reports a directory that is not a vault'

printf 'theme Obsidian tests passed\n'
