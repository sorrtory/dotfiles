#!/usr/bin/env bash
# Neovim's side of the theme: which colorscheme each theme loads, whether the
# transparency switch reaches the editor, that an override in home.nix lands
# on the highlight it names, and that a machine without the generated data
# still starts. Runs the real configs/nvim against the real plugin directory.
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
command -v nvim >/dev/null || fail 'nvim must be on PATH'

plugins="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
[[ -d $plugins/lazy ]] || fail "no installed plugins in $plugins/lazy; run nvim once first"

# The editor's own config, with the theme data and plugins where it looks for
# them: plugins are the real ones, so the test neither installs nor updates.
mkdir -p "$TEST_ROOT/config" "$TEST_ROOT/data/dotfiles/theme" "$TEST_ROOT/state"
ln -s "$REPO_ROOT/configs/nvim" "$TEST_ROOT/config/nvim"
ln -s "$plugins" "$TEST_ROOT/data/nvim"

# What Home Manager would write for a given theme and switch.
theme_file() {
  nix build --impure --no-link --print-out-paths --expr "((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
    modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) ($1); }) ];
  }).config.dotfiles.theme.liveFiles.\"nvim.lua\"" 2>/dev/null || fail "theme data for $1"
}

# Neovim's own report of what it ended up with.
report() {
  XDG_CONFIG_HOME="$TEST_ROOT/config" XDG_DATA_HOME="$TEST_ROOT/data" \
  XDG_STATE_HOME="$TEST_ROOT/state" \
    timeout 120 nvim --headless -c 'lua
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local comment = vim.api.nvim_get_hl(0, { name = "Comment" })
      io.write(table.concat({
        vim.g.colors_name or "none",
        tostring(vim.g.transparent_enabled),
        normal.bg and string.format("#%06x", normal.bg) or "none",
        comment.fg and string.format("#%06x", comment.fg) or "none",
      }, " "))' -c qa 2>/dev/null
}

for theme in gruvbox autumn-glass onedark; do
  for transparency in true false; do
    install -m 644 "$(theme_file "{ name = \"$theme\"; transparency = $transparency; }")" \
      "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
    read -r scheme transparent background _ <<<"$(report)"

    case $theme in
      gruvbox) want_scheme=gruvbox ;;
      onedark) want_scheme=onedark ;;
      # A theme with no plugin of its own is drawn from the palette.
      *) want_scheme=dotfiles ;;
    esac
    [[ $scheme == "$want_scheme" ]] ||
      fail "$theme: colorscheme is $scheme, expected $want_scheme"
    [[ $transparent == "$transparency" ]] ||
      fail "$theme transparency=$transparency: editor reports $transparent"

    if [[ $transparency == true ]]; then
      [[ $background == none ]] ||
        fail "$theme: transparent, but Normal still has background $background"
    else
      [[ $background != none ]] ||
        fail "$theme: opaque, but Normal has no background"
    fi
  done
done

# The surfaces the plugins draw are cleared too, not only the editor's own:
# these are the groups transparent.nvim is told about in
# lua/plugins/colorscheme.lua. The plugins are lazy, so they are loaded first,
# then transparency is applied the way its deferred passes do in a session.
surfaces() {
  XDG_CONFIG_HOME="$TEST_ROOT/config" XDG_DATA_HOME="$TEST_ROOT/data" \
  XDG_STATE_HOME="$TEST_ROOT/state" \
    timeout 120 nvim --headless -c 'lua
      require("lazy").load({ plugins = { "neo-tree.nvim", "telescope.nvim", "lualine.nvim" } })
      pcall(require("transparent").clear)
      local out = {}
      for _, group in ipairs({ "NormalFloat", "FloatBorder", "NeoTreeNormal", "TelescopeNormal", "StatusLine" }) do
        local hl = vim.api.nvim_get_hl(0, { name = group })
        out[#out + 1] = group .. "=" .. (hl.bg and string.format("#%06x", hl.bg) or "none")
      end
      io.write(table.concat(out, " "))' -c qa 2>/dev/null
}

install -m 644 "$(theme_file '{ name = "autumn-glass"; transparency = true; }')" \
  "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
for pair in $(surfaces); do
  [[ $pair == *=none ]] || fail "transparent, but $pair"
done
install -m 644 "$(theme_file '{ name = "autumn-glass"; transparency = false; }')" \
  "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
opaque_surfaces=$(surfaces)
[[ $opaque_surfaces != *=none* ]] || fail "opaque, but a surface has no background: $opaque_surfaces"

# An override in home.nix reaches the highlight it names, whichever theme is
# active: the plugins take it through their own override option, and the
# generated colorscheme through the same table.
for theme in gruvbox autumn-glass onedark; do
  install -m 644 "$(theme_file "{
    name = \"$theme\";
    transparency = false;
    overrides.neovim = { highlights.Comment = { fg = \"#ff00ff\"; italic = false; }; };
  }")" "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
  read -r _ _ _ comment <<<"$(report)"
  [[ $comment == "#ff00ff" ]] || fail "$theme: overridden Comment is $comment"
done

# A machine with the configuration but no Home Manager: no generated data, so
# the editor falls back rather than failing.
rm -f "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
read -r scheme transparent _ _ <<<"$(report)"
[[ $scheme == onedark ]] || fail "without theme data the colorscheme is $scheme"
[[ $transparent == false ]] || fail "without theme data transparency is $transparent"

# Both colorscheme plugins stay installed whichever theme is active.
for plugin in gruvbox.nvim onedark.nvim transparent.nvim; do
  grep -q "\"$plugin\"" "$REPO_ROOT/configs/nvim/lazy-lock.json" ||
    fail "$plugin is not in the lockfile"
done

printf 'theme Neovim tests passed\n'
