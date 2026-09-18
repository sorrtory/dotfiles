# 05 — VS Code

Type: task
Status: ready-for-agent
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

- [ ] Listing extensions shows Gruvbox, One Dark Pro and the Dotfiles theme.
- [ ] Settings select "Dotfiles" permanently, and each theme switch changes it
      after a window reload.
- [ ] Changing a setting in the VS Code UI still saves.

## Comments
