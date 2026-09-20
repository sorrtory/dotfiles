-- The theme chosen in home.nix (modules/theme). Home Manager writes the
-- palette, the transparency switch and the native colorscheme the theme
-- declares into a Lua file; everything here reads that one table.
--
-- On a machine without Home Manager — a remote host with this config copied
-- in — the file is absent and the defaults below apply, so the editor still
-- starts in a dark theme rather than failing.

local defaults = {
  name = "onedark",
  transparency = false,
  colorscheme = "onedark",
  style = "darker",
  colors = {},
  highlights = {},
}

local function load()
  local data_home = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
  local ok, data = pcall(dofile, data_home .. "/dotfiles/theme/nvim.lua")
  if not ok or type(data) ~= "table" then
    return defaults
  end
  -- Only the absent file falls back. A theme that declares no colorscheme
  -- means exactly that: draw one from the palette, do not borrow another
  -- theme's plugin.
  data.colors = data.colors or {}
  data.highlights = data.highlights or {}
  return data
end

local M = load()

-- Whether the theme brings its own plugin, or the colors have to be drawn
-- into highlight groups here (lua/theme/generated.lua).
function M.has_plugin(name)
  return M.colorscheme == name
end

-- Highlight overrides from home.nix, applied on top of whatever colorscheme
-- loaded: `dotfiles.theme.overrides.neovim = { highlights.Comment.fg = ...; }`.
function M.apply_overrides()
  for group, spec in pairs(M.highlights) do
    local ok, current = pcall(vim.api.nvim_get_hl, 0, { name = group })
    vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", ok and current or {}, spec))
  end
end

return M
