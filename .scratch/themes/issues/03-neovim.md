# 03 — Neovim

Type: task
Status: resolved
Blocked by: 01

## What to build

Neovim opens in the current theme and is transparent when the transparency
switch is on.

- gruvbox uses gruvbox.nvim and onedark uses onedark.nvim (keeping today's
  "darker" style), each fed the resolved overrides through its override API.
- autumn-glass, which declares no native plugin, gets a colorscheme generated
  from the palette.
- transparent.nvim, enabled from the transparency switch at startup so its
  cached toggle cannot win; its manual toggle stays for one session.
- Neovim registers as "restart to apply" in the hint.
- Without the generated theme data (a remote host), Neovim still starts with
  a sane default.

## Acceptance

- [x] Headless Neovim reports the expected colorscheme and transparency state
      for every theme and switch combination.
- [x] A Neovim override in `home.nix` changes the highlight it targets.
- [x] Floating windows, the file tree, Telescope and the status line are
      transparent when the switch is on (checked on the host).
- [x] The lockfile carries the new plugins.

## Comments

## Answer

`modules/programs/neovim.nix` writes the palette, the switch and the theme's
declared colorscheme to `~/.local/share/dotfiles/theme/nvim.lua`;
`configs/nvim/lua/theme.lua` reads it and `init.lua` loads the colorscheme
after lazy.nvim has set up. `tests/theme_nvim_test.sh` drives the real
configuration headless against the real plugin directory.

- A theme declares its plugin in `assets.neovim`
  (`{ colorscheme = "gruvbox"; }`, or onedark plus its "darker" style). Both
  plugins are installed whichever theme is active — the inactive one is
  lazy — so a switch is a restart, not an install, and the lockfile pins both.
- autumn-glass declares none, so `configs/nvim/colors/dotfiles.lua` is a real
  colorscheme drawn from the palette in `lua/theme/generated.lua`. Being a
  colorscheme rather than loose highlight calls is what fires the ColorScheme
  event transparent.nvim listens for.
- Overrides reach the plugins through their own APIs (gruvbox's `overrides`
  and `palette_overrides`, onedark's `highlights` and `colors`) and the
  generated scheme through the same table:
  `overrides.neovim = { highlights.Comment = { fg = ...; }; }`. Role
  overrides also reach both plugins' palettes.
- transparent.nvim reads its cache only while `vim.g.transparent_enabled` is
  nil, so the spec's `init` sets it from the switch before the plugin loads.

Checked headless, for all three themes with transparency on and off: the
colorscheme each theme should load, `vim.g.transparent_enabled`, whether
Normal keeps a background, and — with neo-tree, Telescope and lualine loaded —
that NormalFloat, FloatBorder, NeoTreeNormal, TelescopeNormal and StatusLine
lose theirs when transparency is on and keep theirs when it is off. That is
the ticket's fourth check made objective rather than judged by eye; how it
looks on a real screen is still worth a glance on the host.

The `:Lazy sync` that installed the plugins also bumped three unrelated ones;
those were pinned back and restored, so the lockfile carries only gruvbox.nvim
and transparent.nvim.
