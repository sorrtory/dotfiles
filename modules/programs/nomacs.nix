{ lib, pkgs, ... }:

let
  # Qt's default Wayland SHM presentation stutters on the current host's
  # high-resolution display. RHI keeps widget painting on the CPU but uses
  # OpenGL/EGL for composition and presentation, which is smooth here.
  # Drop this wrapper once default native Wayland presentation is smooth.
  nomacs = pkgs.symlinkJoin {
    name = "nomacs-${pkgs.nomacs.version}";
    paths = [ pkgs.nomacs pkgs.nomacs.man ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/nomacs" \
        --set-default QT_WIDGETS_RHI 1 \
        --set-default QT_WIDGETS_RHI_BACKEND opengl
    '';
    meta = pkgs.nomacs.meta // { outputsToInstall = [ "out" ]; };
  };
in
{
  home.packages = [ nomacs ];

  # Settings live in a QSettings ini that nomacs itself keeps rewriting
  # (window geometry, recent files, ...), so this can only seed a fresh
  # profile rather than own the file outright. themeName312 follows the
  # system light/dark preference instead of nomacs's own light default, and
  # appMode=1 starts in frameless mode (the mode F10 toggles), matching the
  # GUI choices already made on this machine.
  home.activation.seedNomacsSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/nomacs/Image Lounge.conf"
    if [[ ! -e $settings ]]; then
      run mkdir -p "$(dirname "$settings")"
      run install -m644 ${pkgs.writeText "nomacs-settings.conf" ''
        [AppSettings]
        appMode=1

        [DisplaySettings]
        themeName312=System.css
      ''} "$settings"
    fi
  '';
}
