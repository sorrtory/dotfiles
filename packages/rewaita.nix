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

    # Upstream's Firefox transparency is `* { opacity }`, which fades text and
    # web pages too and compounds with nesting depth. The theme's background
    # colors are already translucent rgba() (see utils.py below), but the
    # template paints them on nested containers, and stacked 90% layers add up
    # to opaque. Firefox also gives its window an alpha channel only while the
    # root (#main-window) background is fully transparent, which is how its
    # own GTK CSD styling draws the window color on body instead. Do the same:
    # clear the root and the containers, and tint the body once. The tab panel
    # behind pages is cleared too, so pages that userContent.css makes
    # transparent (configs/firefox/userContent.css) show that same tint. The
    # selected tab keeps its card color as a highlight.
    substituteInPlace src/themes/firefox_gnome_theme.py \
      --replace-fail 'extra_css += "* { opacity: 96% !important; }"' \
        'extra_css += "#tabbrowser-tabpanels { --tabpanel-background-color: transparent !important; } #main-window, #tabbrowser-tabbox, #tabbrowser-tabpanels, .browserSidebarContainer, .browserContainer, .browserStack, #navigator-toolbox, #nav-bar, #TabsToolbar, #toolbar-menubar, #PersonalToolbar, #browser, .browser-toolbar, .tabbrowser-arrowscrollbox, .tabbrowser-tab:not([selected]) .tab-background { background-color: transparent !important; } #main-window > body { background-color: var(--headerbar-bg-color) !important; }"'
    substituteInPlace src/utils.py \
      --replace-fail '0.82)' '0.90)' \
      --replace-fail 'opacity: 0.95' 'opacity: 0.90'
  '';
})
