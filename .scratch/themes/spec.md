# Spec: switchable color themes

Status: ready-for-agent

## Why

Every themed app carries its own colors today. Rewaita's Gruvbox Medium drives
GNOME and Firefox, WezTerm and Sublime carry hand-tweaked Gruvbox, AyuGram,
Obsidian and Spotify carry the brown Autumn Glass palette, VS Code runs a
Gruvbox extension installed by hand, and Neovim runs an opaque onedark.nvim.
Changing the look means editing each app separately, and nothing keeps them
in step.

## Decisions (settled by grilling)

### Themes and switches

- **N themes**, each a palette file, all this repository's own: they start
  from an upstream palette and may diverge from it where the result looks
  better, with the divergence recorded in the palette file and its provenance
  in the README (decided 2026-09-20; no external theme collection or
  generator, see Out of scope). Adding a theme is adding a palette file.
  The first three:
  - **gruvbox** — the main theme, from Rewaita's Gruvbox Medium.
  - **autumn-glass** — the espresso/copper Autumn Glass family, with text
    brighter than stock and Gruvbox's bright ANSI set as the normal colors
    (the tweaks WezTerm carries today move here). Applied to every app.
  - **onedark** — One Dark Pro, based on Rewaita's One Dark palette.
- Two independent switches in `home.nix`: the theme, and **transparency**
  (on/off). Every theme works both ways.
- Only dark variants. No light mode, and no hooks for one.
- Switching is `home-manager switch` only. There is no runtime switch command,
  and no live-editing of theme files: a theme change is a Nix change.

### Palette model

- A palette exports **semantic roles** plus **16 ANSI colors**. Roles, roughly:
  base, mantle, surface, overlay, text, subtext, muted, accent, accent2, error,
  warning, success, info. Theme files may name colors natively inside
  (`gruvbox.orange`) but export only roles.
- **Overrides**: an app sees the global roles with overrides layered on top,
  resolved in this order: global roles → the theme's override for that app →
  the operator's override in `home.nix`. An override value is either a hex or
  a function of the roles (`r: { base = r.mantle; }`), so remaps follow every
  theme while hexes pin one-offs. Switching the theme swaps the theme-level
  overrides with it.
- **Transparency** is a small alpha table (window, surface, popup), defaulting
  to today's numbers (0.9 for windows). Apps take alphas from it; per-app
  overrides work the same way as colors.
- A theme can also carry non-color assets, all optional with fallbacks: GNOME
  accent, icon theme, wallpaper, Telegram chat background.
- A theme missing a required role (base roles or ANSI) is an **evaluation
  error**. Anything else missing falls back: no app override → global roles,
  no native editor theme → generated, no wallpaper → unchanged.

### Consumers

- **App themes are generated from the palette** by Nix: Rewaita CSS, Telegram,
  Obsidian, Sublime, Spotify, WezTerm. Rewaita becomes a consumer, not the
  baseline: the palette is the one source of truth, and the gruvbox palette
  starts from Rewaita's Gruvbox Medium hexes so today's GNOME look holds.
- **Editors use a native theme when the theme declares one** (gruvbox.nvim,
  onedark.nvim, the Gruvbox and One Dark Pro VS Code extensions) and receive
  overrides through the native override API (the Neovim plugins' overrides,
  VS Code's `workbench.colorCustomizations`). A theme without a native one,
  like autumn-glass, gets a generated theme.
- **Stable names**: where an app's own config names a theme, it names a fixed
  "Dotfiles" theme, and Nix decides what is behind it. The repo configs do not
  change when the theme does.
- Neovim transparency uses transparent.nvim, driven by the transparency switch.

### Applying a switch

Activation never restarts or signals a program.

| App | After a switch | One-time setup |
|---|---|---|
| GNOME Shell, GTK, Firefox chrome | Live: activation runs Rewaita in the session, though a GTK program reads its colors at startup, so open windows keep theirs (found on the VM, 2026-09-20) | none |
| WezTerm, Sublime | Live: they watch their files | none |
| Wallpaper, accent, icons | Live through dconf | none |
| Neovim, VS Code, Spotify | Next start (VS Code: Reload Window) | none |
| Telegram (AyuGram) | Next start: it re-reads the file every launch | Load the fixed-path theme file once |
| Obsidian | Next start | Link the fixed-path theme into each vault once |

- Telegram and Obsidian read their theme through **fixed paths** that Home
  Manager repoints each generation, so the one-time setup never has to be
  redone after a switch, only on a new vault or machine.
- **The hint**: one combined notice at the end of activation, only when the
  theme or transparency changed. It lists what updated live, what to restart,
  and missing Obsidian links in vaults activation knows about. If Rewaita could
  not apply live (outside a GNOME session, e.g. over SSH), GNOME moves to a
  "log out and back in" line.
- The README explains each one-time step and why it cannot be automated.

### Telegram findings (research, 2026-09-18)

- The applied theme lives in encrypted `tdata` files. The key needs no
  passcode, but writing them means reimplementing Telegram's storage format;
  rejected as brittle.
- No CLI flag applies a theme. `AyuGram file.tdesktop-theme` opens "send to
  chat", not a preview.
- A theme chosen once from a file is **re-read from that path at every
  startup**, and a changed file replaces the cached one. This works on the
  installed AyuGram 7.0.9 and is the chosen flow.
- Telegram Desktop 7.2.6 added a local control command, `theme-apply`, that
  applies instantly after a one-time in-app opt-in. AyuGram 7.0.9 lacks it.
  Anything talking to AyuGram's socket must run in the VPN wrapper's network
  namespace.

## Out of scope

- Light themes.
- Restarting or reloading programs from activation.
- Writing Telegram's `tdata`.
- Stylix or base16 frameworks: they would fight Rewaita and the native
  configs, and give up per-app overrides. Terminal scheme collections such as
  Gogh for the same reason from the other end: they carry a terminal's 16
  colors and none of the roles the other apps need, and install by script.

## Definition of done

- `nix flake check` and the activation package build pass for every theme
  with transparency on and off.
- On the Ubuntu GNOME VM, switching between all three themes recolors every
  consumer as the table says, and the hint lists exactly what changed.
- Rendering autumn-glass reproduces today's Telegram, Obsidian and Spotify
  look, and gruvbox reproduces today's GNOME look.
- Transparency, blur and GPU-dependent looks are confirmed on the host.
