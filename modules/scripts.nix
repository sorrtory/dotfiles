{ pkgs, ... }:

let
  archive = pkgs.writeShellApplication {
    name = "archive";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils pkgs.rsync ];
    text = builtins.readFile ../scripts/bin/archive.sh;
  };

  # gocryptfs comes from Nixpkgs, as the package policy asks. Its setuid FUSE
  # helper cannot: a store path is never setuid-root, so the command finds the
  # host's and says so plainly when a host has none.
  vault = pkgs.writeShellApplication {
    name = "vault";
    # zenity and the file manager are deliberately absent: they are looked up
    # on the caller's PATH, so a machine without them gets a clear message
    # rather than a store path that cannot talk to its session.
    runtimeInputs = [ pkgs.coreutils pkgs.gnused pkgs.gocryptfs ];
    text = builtins.readFile ../scripts/bin/vault.sh;
  };
in
{
  home.file.".local/bin/archive".source = "${archive}/bin/archive";
  home.file.".local/bin/vault".source = "${vault}/bin/vault";
}
