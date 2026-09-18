{ pkgs, unstablePkgs, ... }:

let
  archive = pkgs.writeShellApplication {
    name = "archive";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.rsync ];
    text = builtins.readFile ../scripts/bin/archive.sh;
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
