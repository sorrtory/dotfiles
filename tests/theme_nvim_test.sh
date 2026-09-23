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

# What Home Manager would write for a given theme and switch. liveFiles is
# keyed by the absolute path activation writes to, not by a bare file name.
theme_data_path="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/theme/nvim.lua"

theme_file() {
  nix build --impure --no-link --print-out-paths --expr "((builtins.getFlake \"$REPO_ROOT\").homeConfigurations.z.extendModules {
    modules = [ ({ lib, ... }: { dotfiles.theme = lib.mapAttrs (_: lib.mkForce) ($1); }) ];
  }).config.dotfiles.theme.liveFiles.\"$theme_data_path\"" 2>/dev/null || fail "theme data for $1"
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

for theme in gruvbox autumn-leaves onedark; do
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

install -m 644 "$(theme_file '{ name = "autumn-leaves"; transparency = true; }')" \
  "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
for pair in $(surfaces); do
  [[ $pair == *=none ]] || fail "transparent, but $pair"
done
install -m 644 "$(theme_file '{ name = "autumn-leaves"; transparency = false; }')" \
  "$TEST_ROOT/data/dotfiles/theme/nvim.lua"
opaque_surfaces=$(surfaces)
[[ $opaque_surfaces != *=none* ]] || fail "opaque, but a surface has no background: $opaque_surfaces"

# An override in home.nix reaches the highlight it names, whichever theme is
# active: the plugins take it through their own override option, and the
# generated colorscheme through the same table.
for theme in gruvbox autumn-leaves onedark; do
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

# Markdown is mostly prose, so the little color a page has comes from a handful
# of groups; when they collapse onto one role the file reads as one color,
# which is what the heading ramp and the link treatment in
# lua/theme/generated.lua are for. Naming those groups is worth nothing unless
# the parser actually produces the captures they name, so this parses a real
# buffer and reports what the captures in it resolve to, rather than asking for
# highlight groups by name and believing the answer.
cat >"$TEST_ROOT/sample.md" <<'MARKDOWN'
# One

## Two

### Three

#### Four

> A quote.

A `span` and a [label](https://example.com), then a list:

- item
MARKDOWN

install -m 644 "$(theme_file '{ name = "autumn-leaves"; transparency = false; }')" \
  "$TEST_ROOT/data/dotfiles/theme/nvim.lua"

markdown_colors() {
  XDG_CONFIG_HOME="$TEST_ROOT/config" XDG_DATA_HOME="$TEST_ROOT/data" \
  XDG_STATE_HOME="$TEST_ROOT/state" \
    timeout 120 nvim --headless -c "lua
      local buf = vim.fn.bufadd('$TEST_ROOT/sample.md')
      vim.fn.bufload(buf)
      vim.bo[buf].filetype = 'markdown'
      local parser = vim.treesitter.get_parser(buf, 'markdown')
      parser:parse(true)
      -- The group a capture is drawn in is the capture plus its language, so
      -- collect the pairs the parser really emitted.
      local lang = {}
      parser:for_each_tree(function(tree, ltree)
        local query = vim.treesitter.query.get(ltree:lang(), 'highlights')
        if not query then return end
        for id in query:iter_captures(tree:root(), buf, 0, -1) do
          lang['@' .. query.captures[id]] = ltree:lang()
        end
      end)
      local out = {}
      for _, capture in ipairs({
        '@markup.heading.1', '@markup.heading.2', '@markup.heading.3',
        '@markup.heading.4', '@markup.link.label', '@markup.quote',
        '@markup.raw', '@markup.list',
      }) do
        local group = lang[capture] and (capture .. '.' .. lang[capture])
        local hl = group and vim.api.nvim_get_hl(0, { name = group, link = false }) or {}
        out[#out + 1] = capture .. '='
          .. (lang[capture] == nil and 'uncaptured'
              or (hl.fg and string.format('#%06x', hl.fg) or 'none'))
      end
      io.write(table.concat(out, ' '))" -c qa 2>/dev/null
}

declare -A seen_color=()
for pair in $(markdown_colors); do
  capture=${pair%%=*}
  color=${pair#*=}
  [[ $color != uncaptured ]] ||
    fail "markdown: nothing in the buffer is captured as $capture"
  [[ $color != none ]] ||
    fail "markdown: $capture has no color of its own"
  [[ -z ${seen_color[$color]:-} ]] ||
    fail "markdown: $capture and ${seen_color[$color]} are both $color"
  seen_color[$color]=$capture
done
(( ${#seen_color[@]} == 8 )) ||
  fail "markdown: expected 8 distinct colors, got ${#seen_color[@]}"

printf 'theme Neovim tests passed\n'
