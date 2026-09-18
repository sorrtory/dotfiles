{ config, lib, pkgs, ... }:

let
  # gocryptfs comes from Nixpkgs, as the package policy asks. Its setuid FUSE
  # helper cannot: a store path is never setuid-root, so the command finds the
  # host's and says so plainly when a host has none.
  #
  # zenity, the file manager and Obsidian are deliberately absent from the
  # runtime inputs. They are looked up on the caller's PATH, so a machine
  # without them gets a clear message rather than a store path that cannot
  # talk to its session.
  #
  # libnotify is a D-Bus client and nothing more, so unlike zenity it works
  # from the store. util-linux is for toggle's flock.
  vault = pkgs.writeShellApplication {
    name = "vault";
    runtimeInputs = [ pkgs.coreutils pkgs.gnused pkgs.gocryptfs pkgs.libnotify pkgs.util-linux ];
    # Baked in rather than read from the session, so a lock or unlock from a
    # terminal moves the desktop entry as well. An explicit value still wins.
    text = ''
      : "''${VAULT_DESKTOP_ENTRY=${lib.escapeShellArg config.dotfiles.desktopVault}}"
    '' + builtins.readFile ../../scripts/bin/vault.sh;
  };
in
{
  # The one vault the desktop acts on, and nothing more than that.
  #
  # The command has no global vault and no registry: it acts on the path it is
  # given, or ./Vault in the working directory. This option does not change
  # that, and vault.sh never reads it. It exists because a keybinding and a
  # desktop entry have nowhere to type a path, so they have to carry one. The
  # alternative was the same literal in two modules, which is the drift that
  # made the knowledge database need fixing in the first place. The package
  # below carries it as VAULT_DESKTOP_ENTRY, which only says which vault the
  # desktop entry shows.
  #
  # It says nothing about what is inside. Notes/ is created by `vault notes`
  # within whichever vault it is handed, so pointing this elsewhere moves the
  # notes with it.
  options.dotfiles.desktopVault = lib.mkOption {
    type = lib.types.str;
    default = "${config.home.homeDirectory}/Vault";
    example = "/home/z/Documents/Private";
    description = "The vault <Super>n opens and the Vault desktop entry locks and unlocks.";
  };

  config = {
    home.file.".local/bin/vault".source = "${vault}/bin/vault";

    # One launcher that locks the vault when it is open and opens it when it
    # is locked, with its name and padlock following the state. That cannot be
    # a Home Manager entry: those are fixed at build time. vault writes
    # ~/.local/share/applications/vault.desktop itself on every change, and
    # activation writes it once so it exists before the first change and
    # points at the current store path.
    #
    # Locking asks its retry/cancel/force question through a dialog when it is
    # started this way, so the blocked case is answerable here too.
    home.activation.vaultEntry = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${vault}/bin/vault entry
    '';

  # Ending the graphical session ends access to the vault.
  #
  # Nothing here runs while the session is up: a oneshot that remains after
  # exit is a unit systemd considers active without a process, so the cost is
  # a bookkeeping entry and no daemon. ExecStart only corrects the desktop
  # entry, which a crash or power loss can leave saying the vault is open.
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
      ExecStart = "${vault}/bin/vault entry";
      ExecStop = "${vault}/bin/vault lock --all --force";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
  };
}
