{ lib, pkgs, ... }:

{
  home.packages = [ pkgs.nomacs ];

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
