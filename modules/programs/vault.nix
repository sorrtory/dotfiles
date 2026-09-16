{ pkgs, ... }:

let
  # gocryptfs comes from Nixpkgs, as the package policy asks. Its setuid FUSE
  # helper cannot: a store path is never setuid-root, so the command finds the
  # host's and says so plainly when a host has none.
  #
  # zenity, the file manager and Obsidian are deliberately absent from the
  # runtime inputs. They are looked up on the caller's PATH, so a machine
  # without them gets a clear message rather than a store path that cannot
  # talk to its session.
  vault = pkgs.writeShellApplication {
    name = "vault";
    runtimeInputs = [ pkgs.coreutils pkgs.gnused pkgs.gocryptfs ];
    text = builtins.readFile ../../scripts/bin/vault.sh;
  };
in
{
  home.file.".local/bin/vault".source = "${vault}/bin/vault";

  # Ending the graphical session ends access to the vault.
  #
  # Nothing here runs while the session is up: a oneshot that remains after
  # exit is a unit systemd considers active without a process, so the cost is
  # a bookkeeping entry and no daemon. Only ExecStop does anything.
  #
  # It is bound to graphical-session.target rather than to the user manager,
  # because user lingering is enabled: user@.service keeps running after
  # logout, and a gocryptfs daemon started from a launcher sits in its
  # app.slice, which no session stop reaches. graphical-session.target is what
  # actually stops when the operator logs out.
  #
  # Shutdown needs none of this. systemd sends SIGTERM to everything, and
  # gocryptfs unmounts and exits on it; that is verified, not assumed.
  #
  # --force, because there is nobody at the screen to answer a question about
  # blockers, and --all, because the session may have unlocked more than the
  # one vault the <Super>n binding knows about.
  systemd.user.services.vault-lock = {
    Unit = {
      Description = "Lock the private vaults when the graphical session ends";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop = "${vault}/bin/vault lock --all --force";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
