{ config, lib, pkgs, ... }:

# Exact-path user-namespace allowances for Ubuntu's
# kernel.apparmor_restrict_unprivileged_userns. Modules register the ELF
# executables they need; Home Manager only generates the profiles, and the
# explicit apparmor bootstrap phase installs them with sudo. See
# docs/VESKTOP-APPARMOR.md.

let
  cfg = config.dotfiles.apparmor;

  allowance = {
    options = {
      executable = lib.mkOption {
        type = lib.types.str;
        description = ''
          Absolute path of the ELF executable the profile attaches to. Never a
          wrapper script or a wildcard.
        '';
      };
      usedBy = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = ''
          Packages that must run this exact executable. The build fails when it
          is missing from one of their closures, such as after an update moves
          an application to another Electron.
        '';
      };
    };
  };

  profiles = pkgs.runCommandLocal "dotfiles-apparmor-profiles" { } ''
    mkdir "$out"
    ${lib.concatStrings (lib.mapAttrsToList (name: a: ''
      exe=${lib.escapeShellArg a.executable}
      if [[ ! -f $exe || $(head -c 4 "$exe") != $'\x7fELF' ]]; then
        echo "AppArmor attachment for dotfiles-${name} is not an ELF executable: $exe" >&2
        exit 1
      fi
      ${lib.concatMapStrings (package: ''
        if ! grep -qxF "$(cut -d/ -f1-4 <<<"$exe")" ${pkgs.closureInfo { rootPaths = [ package ]; }}/store-paths; then
          echo "dotfiles-${name}: ${package.name} does not use $exe" >&2
          exit 1
        fi
      '') a.usedBy}
      substitute ${./apparmor.profile} "$out/dotfiles-${name}" \
        --subst-var-by name "dotfiles-${name}" --subst-var-by executable "$exe"
    '') cfg.usernsAllowances)}
  '';
in
{
  # Several modules may register the same name, as applications sharing one
  # Nixpkgs Electron do. Their executables must then be identical, or
  # evaluation reports conflicting definitions.
  options.dotfiles.apparmor.usernsAllowances = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule allowance);
    default = { };
    description = "User-namespace allowances, installed as dotfiles-<name>.";
  };

  config = lib.mkIf (cfg.usernsAllowances != { }) {
    xdg.dataFile."dotfiles/apparmor".source = profiles;

    # Never escalates: it only says when the phase needs running again, which
    # after a flake update moving these packages is otherwise a silent abort.
    home.activation.checkAppArmorProfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      restriction=/proc/sys/kernel/apparmor_restrict_unprivileged_userns
      if [[ -r $restriction && $(<"$restriction") == 1 ]]; then
        for profile in ${profiles}/*; do
          if ! cmp -s "$profile" "/etc/apparmor.d/''${profile##*/}"; then
            warnEcho "AppArmor profile ''${profile##*/} is missing or stale, so the program it allows cannot start. Run: ./scripts/bootstrap.sh install apparmor"
            break
          fi
        done
      fi
    '';
  };
}
