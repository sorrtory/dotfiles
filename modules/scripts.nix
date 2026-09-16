{ pkgs, ... }:

let
  archive = pkgs.writeShellApplication {
    name = "archive";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.rsync ];
    text = builtins.readFile ../scripts/bin/archive.sh;
  };
in
{
  home.file.".local/bin/archive".source = "${archive}/bin/archive";
}
