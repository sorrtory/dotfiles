-- The colorscheme follows the theme in home.nix (modules/theme). A theme that
-- declares a plugin gets that plugin, fed this palette through the plugin's
-- own override API; a theme that declares none is drawn by colors/dotfiles.lua
-- from the same palette. init.lua is where the chosen one is loaded.
--
-- Both plugins stay installed whichever theme is active, so switching is a
-- restart rather than a plugin install, and lazy-lock.json pins them both.

local theme = require("theme")
local c = theme.colors

return {
  {
    "ellisonleao/gruvbox.nvim",
    lazy = not theme.has_plugin("gruvbox"),
    priority = 1000,
    config = function()
      require("gruvbox").setup({
        terminal_colors = true,
        transparent_mode = theme.transparency,
        -- Gruvbox's own names, taken from the palette so that an override in
        -- home.nix reaches the plugin rather than only the terminal.
        palette_overrides = {
          dark0 = c.base,
          dark0_hard = c.mantle,
          dark1 = c.surface,
          dark2 = c.overlay,
          light1 = c.text,
          light2 = c.subtext,
          light4 = c.muted,
          bright_red = c.brightRed,
          bright_green = c.brightGreen,
          bright_yellow = c.brightYellow,
          bright_blue = c.brightBlue,
          bright_purple = c.brightMagenta,
          bright_aqua = c.brightCyan,
          bright_orange = c.accent,
        },
        overrides = theme.highlights,
      })
    end,
  },

  {
    "navarasu/onedark.nvim",
    lazy = not theme.has_plugin("onedark"),
    priority = 1000,
    config = function()
      require("onedark").setup({
        style = theme.style or "darker",
        transparent = theme.transparency,
        colors = {
          black = c.mantle,
          bg0 = c.base,
          bg1 = c.surface,
          bg2 = c.surface,
          bg3 = c.overlay,
          bg_d = c.mantle,
          fg = c.text,
          grey = c.muted,
          light_grey = c.subtext,
          red = c.error,
          green = c.success,
          yellow = c.warning,
          blue = c.accent,
          purple = c.accent2,
          cyan = c.info,
        },
        highlights = theme.highlights,
      })
    end,
  },

  {
    -- Transparency is the switch in home.nix, not a remembered toggle: this
    -- plugin caches its last state and reads the cache only when
    -- vim.g.transparent_enabled is still nil, so setting it before the plugin
    -- loads makes the switch win at every start. :TransparentToggle still
    -- works, for the rest of that session.
    "xiyaowong/transparent.nvim",
    lazy = false,
    priority = 1100,
    init = function()
      vim.g.transparent_enabled = theme.transparency
    end,
    opts = {
      -- Everything this configuration draws that has a background of its own.
      extra_groups = {
        "NormalFloat",
        "FloatBorder",
        "FloatTitle",
        "NeoTreeNormal",
        "NeoTreeNormalNC",
        "NeoTreeEndOfBuffer",
        "NeoTreeWinSeparator",
        "TelescopeNormal",
        "TelescopeBorder",
        "TelescopePromptNormal",
        "TelescopePromptBorder",
        "TelescopeResultsNormal",
        "TelescopePreviewNormal",
        "Pmenu",
        "PmenuSbar",
        "SignColumn",
        "StatusLine",
        "StatusLineNC",
        "WhichKeyFloat",
        "NotifyBackground",
      },
    },
  },
}
