# 01 — MPV module and native configuration

Status: ready-for-agent

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
