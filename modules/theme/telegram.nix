{ config, lib, pkgs, ... }:

# Telegram's side of the theme. It lives here rather than beside the AyuGram
# package in modules/programs/vpnized-apps, because none of it is about the
# VPN: it is one more translator from the palette, plus the packing step that
# translator's format needs. The app only opts in.
#
# A .tdesktop-theme is a zip of the palette and a chat background. The
# background is the theme's wallpaper, the same picture GNOME shows, which
# lives in the home directory rather than this generation — so the zip is
# packed during activation rather than built here. A theme whose wallpaper is
# missing gets one solid color. Either way the file is named background.*,
# never tiled.*, which Telegram would repeat as a pattern.

let
  theme = config.dotfiles.theme;
  cfg = theme.telegram;

  # How much of the window the chat area takes beside the chat list, and how
  # hard the wallpaper behind it is blurred. Both were matched by eye to the
  # hand-made Autumn Glass background this replaces.
  chatWidth = 65;
  blur = 18;
  # How far the blurred picture is pulled toward the theme's background, so
  # message bubbles and their text stay legible over it.
  dim = 50;

  colors = pkgs.writeText "colors.tdesktop-theme"
    (import ./telegram-theme.nix { inherit lib; } (theme.forApp "telegram"));
  plainBackground = pkgs.runCommand "telegram-background.png"
    { nativeBuildInputs = [ pkgs.imagemagick ]; }
    "magick -size 1920x1080 xc:${lib.escapeShellArg (theme.forApp "telegram").base} $out";
in
{
  options.dotfiles.theme.telegram = {
    enable = lib.mkEnableOption "the generated Telegram theme, for a Telegram client that is installed";

    path = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${theme.dataDir}/telegram/Dotfiles.tdesktop-theme";
      description = ''
        The fixed path the packed theme is written to, which the client is
        pointed at once by hand and re-reads at every start.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # AyuGram keeps the applied theme in its encrypted tdata, which nothing
    # here writes, but a theme chosen from a file is read again from that
    # path at every start. So the theme is generated to one fixed path,
    # chosen from there once, and each switch shows at the next start.
    home.activation.dotfilesThemeTelegram = lib.hm.dag.entryAfter [ "dotfilesThemeInit" ] ''
      work=$(mktemp -d)
      trap 'rm -rf -- "$work"' EXIT
      cp ${colors} "$work/colors.tdesktop-theme"
      # The chat background is the desktop wallpaper as it would look
      # through the window: the chat list covers the left third, so that
      # part is cropped away and what is left lines up with the picture
      # behind the window, and it is blurred, because a drawing is too busy
      # to read messages over. Re-encoding also keeps the theme under
      # Telegram's 5 MB limit, which a wallpaper alone often exceeds.
      if [[ -f ${lib.escapeShellArg theme.wallpaper} ]] &&
        ${lib.getExe pkgs.imagemagick} ${lib.escapeShellArg theme.wallpaper} \
          -gravity East -crop ${toString chatWidth}%x100%+0+0 +repage \
          -resize '2560x2560>' -blur 0x${toString blur} \
          -fill ${lib.escapeShellArg (theme.forApp "telegram").base} \
          -colorize ${toString dim}% -strip \
          -quality 82 "$work/background.jpg"
      then
        :
      else
        rm -f "$work/background.jpg"
        cp ${plainBackground} "$work/background.png"
      fi
      # zip stores a timestamp; a fixed one keeps the theme byte-identical
      # between activations, so AyuGram is only handed a changed file when
      # the theme actually changed.
      touch -d 1980-01-02T00:00:00Z "$work"/*
      (cd "$work" && ${lib.getExe pkgs.zip} -qX packed.zip colors.tdesktop-theme background.*)
      if ! cmp -s "$work/packed.zip" ${lib.escapeShellArg cfg.path}; then
        run mkdir -p ${lib.escapeShellArg (builtins.dirOf cfg.path)}
        run cp --no-preserve=mode "$work/packed.zip" ${lib.escapeShellArg cfg.path}
      fi
    '';

    dotfiles.theme.apps.telegram = {
      label = "Telegram";
      apply = "restart";
      setup = "choose ${cfg.path} under Settings → Chat Settings → Choose from file, then Apply";
    };
  };
}
