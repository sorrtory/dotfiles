#!/usr/bin/env bash
# Obsidian's side of the theme: a theme generated per palette at one fixed
# path, named so a vault is linked to it once, still recognisably the
# hand-made Autumn Glass theme it replaces, and a hint that names a vault
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

# The manifest names the theme, and the directory a vault links to has to
# carry that same name for Obsidian to find it.
mapfile -t built < <(files gruvbox)
[[ $(jq -r '.name' "${built[1]}") == Dotfiles ]] ||
  fail 'the manifest does not name the theme Dotfiles'

# The hand-made theme is gone; the generated one is what a vault links to.
[[ ! -e "$REPO_ROOT/configs/obsidian" ]] ||
  fail 'the hand-made Obsidian theme is still in the repository'

# Every variable the hand-made theme set is still set, so no part of the
# window falls back to Obsidian's own dark colors.
wanted=$(git -C "$REPO_ROOT" show HEAD:configs/obsidian/autumn-glass/theme.css 2>/dev/null |
  grep -oP '^\s*--\K[a-z0-9-]+' | sort -u)
[[ -n $wanted ]] || fail 'cannot read the hand-made theme from git to compare against'

for theme in gruvbox autumn-glass onedark; do
  mapfile -t built < <(files "$theme")
  css=${built[0]}
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

# Autumn-glass is the theme this was generated from, so it still has to look
# like it: every value either identical or a near neighbour, apart from the
# code colors, which now read the roles the way the editors do.
mapfile -t built < <(files autumn-glass)
git -C "$REPO_ROOT" show HEAD:configs/obsidian/autumn-glass/theme.css > "$TEST_ROOT/was.css"
python3 - "$TEST_ROOT/was.css" "${built[0]}" <<'PY' || fail 'autumn-glass no longer resembles the theme it was generated from'
import re, sys

def load(path):
    out = {}
    for line in open(path):
        m = re.match(r"\s*--([a-z0-9-]+):\s*(.+?);", line)
        if m:
            out[m.group(1)] = m.group(2).strip()
    return out

def channels(value):
    value = value.strip()
    if value.startswith("#"):
        return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
    m = re.match(r"rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)", value)
    return tuple(float(x) for x in m.groups()) if m else None

# code-string is deliberately the palette's success rather than the sage green
# the hand-made file used, so that a string is one color across every editor.
allowed = {"code-string"}
was, now = load(sys.argv[1]), load(sys.argv[2])
bad = []
for key, before in was.items():
    after = now.get(key, "")
    if before.lower() == after.lower() or key in allowed:
        continue
    a, b = channels(before), channels(after)
    if a is None or b is None or max(abs(x - y) for x, y in zip(a, b)) > 10:
        bad.append(f"{key}: {before} -> {after}")
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY

# The hint names a vault that has no link yet, and goes quiet once it has one.
check=$(nix build --impure --no-link --print-out-paths --expr "
  ((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.pkgs.writeShellScript \"check\"
    (builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.config.dotfiles.theme.apps.obsidian.check)" 2>/dev/null) ||
  fail 'Obsidian registers no check for the hint'

vault="$TEST_ROOT/home/Documents/Knowledge-Database"
mkdir -p "$vault/.obsidian"
HOME="$TEST_ROOT/home" "$check" | grep -q 'Knowledge-Database has no Dotfiles link' ||
  fail 'the hint does not name a vault that is missing the link'

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
