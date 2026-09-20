{ lib, glib, gobject-introspection, makeWrapper, python3, runCommand, wezterm }:

# Stands in for Ptyxis on the session bus so Nautilus's "Open in Console" and
# GNOME's Ptyxis launcher open WezTerm instead. See wezterm-console.py.
let
  python = python3.withPackages (ps: [ ps.pygobject3 ]);
in
runCommand "wezterm-console" {
  nativeBuildInputs = [ makeWrapper ];
  meta.mainProgram = "wezterm-console";
} ''
  install -Dm644 ${./wezterm-console.py} $out/libexec/wezterm-console.py
  makeWrapper ${lib.getExe python} $out/bin/wezterm-console \
    --add-flags $out/libexec/wezterm-console.py \
    --prefix GI_TYPELIB_PATH : ${lib.makeSearchPath "lib/girepository-1.0" [ glib.out gobject-introspection ]} \
    --set-default WEZTERM_CONSOLE_WEZTERM ${lib.getExe wezterm}
''
