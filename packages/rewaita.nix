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
  '';
})
