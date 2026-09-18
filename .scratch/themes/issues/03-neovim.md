# 03 — Neovim

Type: task
Status: ready-for-agent
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

- [ ] Headless Neovim reports the expected colorscheme and transparency state
      for every theme and switch combination.
- [ ] A Neovim override in `home.nix` changes the highlight it targets.
- [ ] Floating windows, the file tree, Telescope and the status line are
      transparent when the switch is on (checked on the host).
- [ ] The lockfile carries the new plugins.

## Comments
