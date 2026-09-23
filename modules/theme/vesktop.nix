{ config, lib, pkgs, ... }:

let
  theme = config.dotfiles.theme;
in
{
  config = lib.mkIf config.dotfiles.vpnizedApps.vesktop.enable {
      # Vencord reads every stylesheet in its themes directory and re-reads
      # one whenever that directory changes, so a switch recolors the running
      # client. The name never changes; what is behind it does. Which themes
      # are enabled is Vencord's own settings file, machine-local state this
      # does not own, so enabling it is a one-time step like Obsidian's.
      dotfiles.theme.liveFiles."${config.xdg.configHome}/vesktop/themes/Dotfiles.css" =
        pkgs.writeText "Dotfiles.css"
          (import ./vesktop-theme.nix { inherit lib; } (theme.forApp "vesktop"));

      dotfiles.theme.apps.vesktop = {
        label = "Vesktop";
        apply = "live";
        setup = "enable Dotfiles under Settings → Themes";
        # Vencord rewrites this file itself, so the enabled list is read back
        # rather than assumed. No file means Vesktop has never started.
        check = ''
          settings=${lib.escapeShellArg "${config.xdg.configHome}/vesktop/settings/settings.json"}
          [[ -e $settings ]] || exit 0
          ${lib.getExe pkgs.jq} -e '(.enabledThemes // []) | index("Dotfiles.css")' "$settings" >/dev/null \
            || echo "Dotfiles is not enabled under Settings → Themes"
        '';
      };
  };
}
