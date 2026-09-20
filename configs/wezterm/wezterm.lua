-- WezTerm re-reads this file on save, so edits apply without a restart.
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Colors come from the theme in home.nix (modules/theme). Activation writes
-- them to a file of their own and rewrites it on a switch; watching it makes
-- that reload the config like an edit here does. Without it, before the
-- first activation or on a machine without Home Manager, WezTerm falls back
-- to its bundled Gruvbox.
local theme_file = (os.getenv("XDG_DATA_HOME") or wezterm.home_dir .. "/.local/share")
  .. "/dotfiles/theme/wezterm.lua"
wezterm.add_to_config_reload_watch_list(theme_file)
local ok, t = pcall(dofile, theme_file)

-- A lone tab needs no bar; it comes back with the second tab.
config.hide_tab_bar_if_only_one_tab = true

if ok and type(t) == "table" then
  config.color_schemes = {
    Dotfiles = {
      foreground = t.text,
      background = t.base,
      cursor_bg = t.text,
      cursor_border = t.text,
      cursor_fg = t.base,
      selection_bg = t.overlay,
      selection_fg = t.text,
      ansi = { t.black, t.red, t.green, t.yellow, t.blue, t.magenta, t.cyan, t.white },
      brights = {
        t.brightBlack, t.brightRed, t.brightGreen, t.brightYellow,
        t.brightBlue, t.brightMagenta, t.brightCyan, t.brightWhite,
      },
      -- The fancy tab bar sits in the title bar WezTerm draws itself on
      -- Wayland, in the desktop's headerbar color.
      tab_bar = {
        background = t.mantle,
        active_tab = { bg_color = t.base, fg_color = t.text },
        inactive_tab = { bg_color = t.mantle, fg_color = t.muted },
        inactive_tab_hover = { bg_color = t.surface, fg_color = t.text },
        new_tab = { bg_color = t.mantle, fg_color = t.muted },
        new_tab_hover = { bg_color = t.surface, fg_color = t.accent },
      },
    },
  }
  config.color_scheme = "Dotfiles"
  config.window_frame = {
    active_titlebar_bg = t.mantle,
    inactive_titlebar_bg = t.mantle,
  }
  -- Only the background is translucent; text stays opaque.
  config.window_background_opacity = t.alpha.window
else
  config.color_scheme = "GruvboxDark"
end

-- Up from WezTerm's 3500, so select all reaches further back.
config.scrollback_lines = 10000

-- Select all, as in Ptyxis. WezTerm has no such action, so this puts the
-- scrollback and screen on the clipboard (wrapped lines rejoined, blank rows
-- around it trimmed), then enters copy mode and highlights the same range.
-- Escape leaves copy mode.
-- https://github.com/wezterm/wezterm/discussions/2026
--
-- The selection steps need their own perform_action call. Inside one
-- act.Multiple they go to the pane that was active before copy mode opened
-- and do nothing; a later call is routed to the copy overlay instead.
local act = wezterm.action
local select_all = act.Multiple({
  act.CopyMode("MoveToScrollbackTop"),
  act.CopyMode({ SetSelectionMode = "Cell" }),
  act.CopyMode("MoveToScrollbackBottom"),
  act.CopyMode("MoveToEndOfLineContent"),
})
config.keys = {
  {
    key = "a",
    mods = "CTRL|SHIFT",
    action = wezterm.action_callback(function(window, pane)
      local rows = pane:get_dimensions().scrollback_rows
      local text = pane:get_lines_as_text(rows)
      window:copy_to_clipboard(text:match("^%s*(.-)%s*$"), "Clipboard")
      window:perform_action(act.ActivateCopyMode, pane)
      window:perform_action(select_all, pane)
    end),
  },
}

-- Installed by modules/packages.nix; its glyphs are what Neovim and Yazi
-- assume the terminal font carries.
config.font = wezterm.font("MesloLGS Nerd Font Mono")
config.font_size = 12

return config
