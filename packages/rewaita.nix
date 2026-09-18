{ fetchFromGitHub, rewaita }:

rewaita.overrideAttrs (old: rec {
  version = "1.1.7";

  src = fetchFromGitHub {
    owner = "SwordPuffin";
    repo = "Rewaita";
    tag = "v${version}";
    hash = "sha256-KGcONTou2ce3FNMhGwsBB0K4DTJugBMxKq7ncRvSvo4=";
  };

  postPatch = (old.postPatch or "") + ''
    # Native Rewaita otherwise puts prefs.json, palette directories and
    # wallpapers directly in ~/.local/share. Keep its mutable data under its
    # own application directory, as the Flatpak does implicitly.
    for source in $(grep -rl 'GLib.get_user_data_dir()' src); do
      substituteInPlace "$source" \
        --replace-fail 'GLib.get_user_data_dir()' \
          'os.path.join(GLib.get_user_data_dir(), "rewaita")'
    done

    # Home Manager owns Firefox's user.js as a read-only Nix-store symlink.
    # Rewaita only needs to create it for unmanaged profiles; touching an
    # existing symlink aborts the profile update before its CSS is written.
    substituteInPlace src/themes/firefox_gnome_theme.py \
      --replace-fail 'Path(f"{result}/user.js").touch()' \
        'if not Path(f"{result}/user.js").exists(): Path(f"{result}/user.js").touch()'

    # Disable Rewaita's accent borders regardless of an older mutable
    # preferences file that may still have its Window Borders toggle enabled.
    substituteInPlace src/utils.py \
      --replace-fail 'colors["border-color"] = colors["accent-color"]' \
        'colors["border-color"] = "transparent"'

    # Firefox needs an explicit root opacity for the translucent surface to be
    # composited; keep the same 90% level as the GTK backgrounds.
    substituteInPlace src/themes/firefox_gnome_theme.py \
      --replace-fail 'extra_css += "* { opacity: 96% !important; }"' \
        'extra_css += "* { opacity: 90% !important; }"'
    substituteInPlace src/utils.py \
      --replace-fail '0.82)' '0.90)' \
      --replace-fail 'opacity: 0.95' 'opacity: 0.90'
  '';
})
