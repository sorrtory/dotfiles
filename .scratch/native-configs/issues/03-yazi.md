# 03 — Yazi

Status: ready-for-agent

## Goal

Let Home Manager own Yazi, its native TOML configuration, and its single
pinned plugin. This removes the last legacy Snap dependency other than the
browser.

## Work

1. Copy `keymap.toml` and `package.toml` from `~/Documents/configs/yazi/` to
   `configs/yazi/`.
2. Create `modules/programs/yazi.nix` with `programs.yazi.enable = true`,
   exposing the TOML files through `mkOutOfStoreSymlink`.
3. Provide the `copy-file-contents` plugin from
   `AnirudhG07/plugins-yazi` at revision `71545f4`, the pin
   `configs/yazi/package.toml` already records. Use `pkgs.yaziPlugins` if it
   carries the plugin; otherwise write a small local package under
   `packages/`.
4. Import the module from `home.nix`.

## Constraints

- `docs/SOFTWARE.md` records Yazi as a *"Legacy Snap"*. The selected policy is
  that no software this repository declares comes from Snap, so this ticket
  must not leave any Snap fallback path in place. Update the row.
- Keep `package.toml` in the repository even though Nix now provides the
  plugin. It is the record of which revision was selected, and deleting it
  loses the provenance of the pin.
- Yazi must find the plugin where it expects it. Verify the plugin actually
  loads rather than only that the file is present; a plugin in the wrong
  directory fails quietly.
- Yazi needs its preview dependencies to be useful. FFmpeg and ImageMagick are
  already global user tools; confirm rather than re-declare them.

## Acceptance

- `nix build .#homeConfigurations.z.activationPackage` succeeds.
- On the staging VM after activation:
  - `yazi` starts and resolves its config into `~/Documents/dotfiles`;
  - `Alt+y` on a text file copies its contents, proving the plugin loaded;
  - `snap list yazi` reports nothing installed.
