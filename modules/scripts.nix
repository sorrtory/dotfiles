{ config, pkgs, unstablePkgs, ... }:

let
  # 7-Zip is only reached by --compress, but it belongs in runtimeInputs rather
  # than being resolved from the caller's PATH: it is an ordinary Nix package,
  # unlike the self-updating yt-dlp below. The root arrives as an environment
  # variable rather than being substituted into the text, so the same script
  # still runs straight from the repository — which is how the tests invoke it
  # — and falls back to ~/Archive when nothing sets it.
  archive = pkgs.writeShellApplication {
    name = "archive";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.rsync pkgs._7zz ];
    # := rather than runtimeEnv, which would export unconditionally and quietly
    # beat a caller that set ARCHIVE_ROOT itself. The configured root is a
    # default, so the documented order — --to, then the environment, then the
    # configuration — is the order that actually happens.
    text = ''
      : "''${ARCHIVE_ROOT:=${config.dotfiles.archive.root}}"
      export ARCHIVE_ROOT
    '' + builtins.readFile ../scripts/bin/archive.sh;
  };

  # The one front door for fetching media. yt-dlp is deliberately absent from
  # runtimeInputs: it is the bootstrap-installed release binary rather than a
  # Nix package, so that `yt-dlp -U` keeps working, and the script resolves it
  # from the caller's PATH. ImageMagick is here because gallery-dl has no image
  # post-processor and the JPEG and PNG conversions drive `magick` through its
  # `--exec`; coreutils supplies the `tr` that snippet uses.
  download = pkgs.writeShellApplication {
    name = "download";
    runtimeInputs = [
      pkgs.aria2
      pkgs.coreutils
      pkgs.imagemagick
      unstablePkgs.gallery-dl
      unstablePkgs.spotdl
    ];
    text = builtins.readFile ../scripts/bin/download.sh;
  };

  # Its counterpart for files already on disk. FFmpeg carries the ffprobe the
  # recipe choice reads, and coreutils the mktemp the palette and cover-art
  # passes need.
  convertTo = pkgs.writeShellApplication {
    name = "convert-to";
    runtimeInputs = [ pkgs.coreutils pkgs.ffmpeg ];
    text = builtins.readFile ../scripts/bin/convert-to.sh;
  };
in
{
  home.file.".local/bin/archive".source = "${archive}/bin/archive";
  home.file.".local/bin/download".source = "${download}/bin/download";
  home.file.".local/bin/convert-to".source = "${convertTo}/bin/convert-to";
}
