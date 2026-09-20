# 05 — VS Code

Type: task
Status: resolved
Blocked by: 01

## What to build

VS Code's theme extensions are declared, and its theme is a local "Dotfiles"
theme that follows the switch.

- First, confirm the Nixpkgs One Dark Pro package ships its theme JSON (the
  extension can generate themes at runtime). If not, stop and record the
  finding here before choosing another route.
- The Gruvbox and One Dark Pro extensions come from Nixpkgs; extensions
  installed by hand keep working.
- A local extension contributes one theme, "Dotfiles": the native theme the
  palette declares (Gruvbox Dark Hard, One Dark Pro), or one generated from
  the palette when none is declared.
- Overrides reach VS Code through its color customizations without anything
  rewriting the operator's settings file.
- VS Code registers as "restart to apply" (Reload Window) in the hint.

## Acceptance

- [x] Listing extensions shows Gruvbox, One Dark Pro and the Dotfiles theme.
- [x] Settings select "Dotfiles" permanently, and each theme switch changes it
      after a window reload.
- [x] Changing a setting in the VS Code UI still saves.

## Comments

## Answer

Nixpkgs' One Dark Pro (3.19.0) does ship its theme JSON: five variants under
`themes/`, and `OneDark-Pro.json` is `#282c34` on `#21252b`, this palette's
base and mantle exactly. Nothing had to be generated at runtime, so the
route the ticket asked about first was never needed.

Built in `modules/programs/vscode.nix`, with the generator for a theme that
names no extension in `modules/theme/vscode-theme.nix`;
`tests/theme_vscode_test.sh` covers all three acceptance lines.

- A palette names its native theme by id and label in
  `assets.vscode = { extension = "jdinhlife.gruvbox"; theme = "Gruvbox Dark
  Hard"; }`. Palettes are plain data and never see `pkgs`, so the module maps
  the id to a package, the way `configs/nvim` maps a colorscheme name to a
  lazy.nvim plugin.
- The label is looked up in the upstream extension's own
  `contributes.themes` with jq at build time, not matched against a file name
  written down here, so a renamed file in a later extension version fails the
  build with the list of labels it does contribute instead of silently
  shipping the wrong theme.
- The local extension `dotfiles.dotfiles-theme` contributes exactly one theme,
  "Dotfiles". `programs.vscode.profiles.default.extensions` holds it and the
  two upstream ones; only the default profile is used, so
  `mutableExtensionsDir` stays on and hand-installed extensions keep working.
- Overrides are VS Code's own color keys under
  `dotfiles.theme.overrides.vscode.colorCustomizations`, the escape hatch
  `highlights` is for Neovim. They are merged into the contributed theme's
  `colors`, last, so an override beats the upstream extension's value —
  and `settings.json` stays an `mkOutOfStoreSymlink` nothing writes to.
- Role overrides still work as everywhere else and reach a generated theme;
  they cannot reach a native one, which is what declaring a native theme
  means.
- Transparency does not reach VS Code: Electron draws an opaque window and the
  spec's transparency switch has nothing to act on here.
