-- WezTerm re-reads this file on save, so edits apply without a restart.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Rewaita's Gruvbox Medium, the desktop theme: WezTerm's bundled GruvboxDark
-- has the same #282828 background and #ebdbb2 foreground. The scheme leaves
-- the tab bar at WezTerm's grey-blue defaults, so it gets Rewaita's headerbar
-- colour here and is registered as a scheme of its own.
local bg, header, fg = "#282828", "#1d2021", "#ebdbb2"
local muted, accent = "#a89984", "#fe8019"

local scheme = wezterm.color.get_builtin_schemes()["GruvboxDark"]

-- More contrast than stock Gruvbox: text is its brightest cream, and the
-- normal colours take Gruvbox's bright variants instead of the dim neutrals,
-- which sit too close to the background. The bright colours are unchanged.
scheme.foreground = "#fbf1c7"
scheme.ansi = {
  "#282828", "#fb4934", "#b8bb26", "#fabd2f",
  "#83a598", "#d3869b", "#8ec07c", "#ebdbb2",
}
scheme.tab_bar = {
  background = header,
  active_tab = { bg_color = bg, fg_color = fg },
  inactive_tab = { bg_color = header, fg_color = muted },
  inactive_tab_hover = { bg_color = "#3c3836", fg_color = fg },
  new_tab = { bg_color = header, fg_color = muted },
  new_tab_hover = { bg_color = "#3c3836", fg_color = accent },
}
config.color_schemes = { ["Gruvbox Rewaita"] = scheme }
config.color_scheme = "Gruvbox Rewaita"

-- The fancy tab bar sits in the title bar WezTerm draws itself on Wayland.
-- A lone tab needs no bar; it comes back with the second tab.
config.hide_tab_bar_if_only_one_tab = true
config.window_frame = {
  active_titlebar_bg = header,
  inactive_titlebar_bg = header,
}

-- Matches the Ptyxis profile in modules/desktops/gnome.nix. Only the
-- background is translucent; text stays opaque.
config.window_background_opacity = 0.9

-- Select all, as in Ptyxis. WezTerm has no such action, so this enters copy
-- mode and selects from the top of the scrollback to the end of the last
-- line; y or Ctrl+Shift+C copies it, Escape leaves.
local act = wezterm.action
config.keys = {
  {
    key = "a",
    mods = "CTRL|SHIFT",
    action = act.Multiple({
      act.ActivateCopyMode,
      act.CopyMode("MoveToScrollbackTop"),
      act.CopyMode({ SetSelectionMode = "Cell" }),
      act.CopyMode("MoveToScrollbackBottom"),
      act.CopyMode("MoveToEndOfLineContent"),
    }),
  },
}

-- Installed by modules/packages.nix; its glyphs are what Neovim and Yazi
-- assume the terminal font carries.
config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 12

return config
