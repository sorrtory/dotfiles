{ config, lib, pkgs, ... }:

let
  proxy = config.dotfiles.localProxy;
  cfg = config.dotfiles.vpnizedApps.ayugram;
  vpn = config.dotfiles.vpn.command;
  ayugramLauncher = pkgs.writeShellApplication {
    name = "AyuGram";
    runtimeEnv = {
      VPN_COMMAND = vpn;
      VPN_AYUGRAM = lib.getExe pkgs.ayugram-desktop;
    };
    text = builtins.readFile ./vpnized-apps/ayugram.sh;
  };
  # The package with its command and desktop entry replaced by the launcher,
  # so the terminal, the icon and tg:// links all go through the VPN. A plain
  # Qt binary, unlike Vesktop's Electron, so it needs no AppArmor userns
  # allowance to run under the VPN command. The entry is DBusActivatable, so
  # GNOME starts it through the D-Bus service file and never reads its Exec;
  # that file is replaced too.
  ayugram = pkgs.symlinkJoin {
    name = "ayugram-vpn-${pkgs.ayugram-desktop.version}";
    paths = [ pkgs.ayugram-desktop ];
    postBuild = ''
      rm "$out/bin/AyuGram" "$out/share/applications/com.ayugram.desktop.desktop" \
        "$out/share/dbus-1/services/com.ayugram.desktop.service"
      ln -s ${lib.getExe ayugramLauncher} "$out/bin/AyuGram"
      substitute ${pkgs.ayugram-desktop}/share/applications/com.ayugram.desktop.desktop \
        "$out/share/applications/com.ayugram.desktop.desktop" \
        --replace-fail 'Exec=env DESKTOPINTEGRATION=1 AyuGram -- %U' \
          'Exec=env DESKTOPINTEGRATION=1 ${lib.getExe ayugramLauncher} -- %U'
      substitute ${pkgs.ayugram-desktop}/share/dbus-1/services/com.ayugram.desktop.service \
        "$out/share/dbus-1/services/com.ayugram.desktop.service" \
        --replace-fail 'Exec=${lib.getExe pkgs.ayugram-desktop}' \
          'Exec=${lib.getExe ayugramLauncher}'
    '';
  };
in
{
  options.dotfiles.vpnizedApps.ayugram.enable =
    lib.mkEnableOption "AyuGram, always launched through the VPN";

  config = lib.mkMerge [
    {
      assertions = [{
        assertion = cfg.enable -> proxy.enable;
        message = "dotfiles.vpnizedApps.ayugram requires dotfiles.localProxy.enable.";
      }];
    }
    (lib.mkIf (proxy.enable && cfg.enable) {
      home.packages = [ ayugram ];

      # Telegram's colors come from the palette like every other themed
      # app; modules/theme/telegram.nix generates and packs the theme, and
      # names the fixed path the client is pointed at once by hand.
      dotfiles.theme.telegram.enable = true;
    })
  ];
}
