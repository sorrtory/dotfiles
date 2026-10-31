{ lib, pkgs, ... }:

let
  # sudo stays host-owned: a Nix-store sudo is not the distro's privileged
  # helper. Pass the exact upstream executable so sudo's secure_path does not
  # need the user profile, and never re-enter this launcher after elevation.
  launcher =
    name:
    pkgs.writeShellApplication {
      inherit name;
      text = ''
        if (( EUID == 0 )); then
          exec ${pkgs.ventoy}/bin/${name} "$@"
        fi

        case "''${1-}" in
          -h|--help${lib.optionalString (name == "ventoy") "|-V|--version"})
            exec ${pkgs.ventoy}/bin/${name} "$@"
            ;;
        esac

        if ! command -v sudo >/dev/null 2>&1; then
          echo '${name}: administrator privileges require the host sudo command.' >&2
          exit 1
        fi
        exec sudo -- ${pkgs.ventoy}/bin/${name} "$@"
      '';
    };
  launchers = map launcher [
    "ventoy"
    "ventoy-web"
  ];

  ventoy = pkgs.symlinkJoin {
    name = "ventoy-${pkgs.ventoy.version}";
    paths = [ pkgs.ventoy ];
    postBuild = lib.concatMapStringsSep "\n" (command: ''
      rm "$out/bin/${command.name}"
      ln -s ${lib.getExe command} "$out/bin/${command.name}"
    '') launchers;
    meta = pkgs.ventoy.meta;
  };
in
{
  home.packages = [ ventoy ];
}
