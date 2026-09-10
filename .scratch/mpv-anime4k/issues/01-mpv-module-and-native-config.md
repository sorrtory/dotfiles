# 01 — MPV module and native configuration

Status: resolved

## Goal

Give this repository an MPV that starts and reads a configuration it owns,
before any script or shader is added to it.

## Work

1. Copy `~/Documents/configs/mpv/mpv.conf` and
   `~/Documents/configs/mpv/input.conf` to `configs/mpv/`. Copy them verbatim;
   later tickets change specific lines with a stated reason.
2. Create `modules/programs/mpv.nix` enabling `programs.mpv`. Follow the
   shape of `modules/programs/vscode.nix`: a `configRoot` let-binding pointing
   at `${config.home.homeDirectory}/Documents/dotfiles/configs/mpv`, then
   `xdg.configFile` entries using
   `config.lib.file.mkOutOfStoreSymlink`.
3. Expose `mpv.conf` at `xdg.configFile."mpv/mpv.conf"` and `input.conf` at
   `xdg.configFile."mpv/input.conf"`.
4. Import `modules/programs/mpv.nix` from `home.nix`.

## Constraints

- `programs.mpv` owns the MPV package. Do not also declare `mpv` in
  `modules/packages.nix`; `docs/DECISIONS.md` forbids declaring the same
  package in both places.
- Do not use `programs.mpv.config` or `programs.mpv.bindings`. The native
  files are readable and heavily commented, and `docs/DECISIONS.md` says to
  keep a readable native config rather than translate it for aesthetics.
- `mkOutOfStoreSymlink` is deliberate here: MPV re-reads its config on
  restart, so live editing is worth having.

## Acceptance

- `nix build .#homeConfigurations.z.activationPackage` succeeds.
- On the staging VM after activation, `~/.config/mpv/mpv.conf` resolves to
  `~/Documents/dotfiles/configs/mpv/mpv.conf`.
- `mpv --idle --vo=null` starts and exits cleanly with no configuration
  parse errors on stderr.

## Comments

Implemented on the host. `configs/mpv/mpv.conf` and `configs/mpv/input.conf`
are byte-identical copies of the legacy files (verified by `sha256sum` before
ticket 04 edited the shader bindings), `modules/programs/mpv.nix` follows the
`vscode.nix` shape, and `home.nix` imports it.

`nix build .#homeConfigurations.z.activationPackage` succeeds and the built
generation's `.config/mpv/{mpv,input}.conf` resolve through their `hm_` store
symlinks to `~/Documents/dotfiles/configs/mpv/`.

Running the built `mpv` against a copy of the migrated config with
`--idle=once --vo=null` exits cleanly with no parse errors. Note that a
`--no-config` run instead produces a `SmartCopyPaste_II` Lua traceback at its
`join_path` call; that is an artifact of having no config directory, not a
packaging fault, and it does not appear once a config directory exists.

Outstanding: the VM half of the acceptance. The `rsync` to the staging VM was
denied by the sandbox in the session that did this work, so activation there,
and with it the `~/.config/mpv/mpv.conf` resolution check on a real
activation, has not run.

## Answer

Resolved. On a normal `bootstrap.sh install home-manager` on the staging VM,
`~/.config/mpv/mpv.conf` and `input.conf` resolve to
`~/Documents/dotfiles/configs/mpv/`, and mpv starts and plays with no
configuration parse error. Nothing under the MPV config tree references
`~/.local/share/configs-manager`, which is the fresh-machine failure this
ticket existed to remove.
