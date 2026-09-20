"""Answer Ptyxis's D-Bus name by opening WezTerm.

Nautilus's "Open in Console" (Ctrl+.) calls org.freedesktop.Application.Open
on org.gnome.Ptyxis, and GNOME launches Ptyxis's DBusActivatable desktop entry
through the same name. Owning that name routes both to WezTerm.
"""

import os
import subprocess
import sys

from gi.repository import Gio, GLib

APP_ID = "org.gnome.Ptyxis"
WEZTERM = os.environ.get("WEZTERM_CONSOLE_WEZTERM", "wezterm")


def directory_for(file):
    # GVFS locations such as sftp:// have a FUSE path; anything without one
    # falls back to home rather than failing the menu action.
    path = file.get_path()
    if path is None:
        return GLib.get_home_dir()
    if not os.path.isdir(path):
        path = os.path.dirname(path)
    return path


def open_wezterm(cwd):
    # A scope of its own keeps WezTerm alive after this service exits and its
    # unit stops; the new window belongs to WezTerm, not to this shim.
    command = [WEZTERM, "start", "--cwd", cwd]
    try:
        subprocess.Popen(
            ["systemd-run", "--user", "--scope", "--collect", "--quiet", "--", *command],
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except FileNotFoundError:
        subprocess.Popen(command, stdin=subprocess.DEVNULL, start_new_session=True)


class Console(Gio.Application):
    def __init__(self):
        super().__init__(
            application_id=APP_ID,
            flags=Gio.ApplicationFlags.IS_SERVICE | Gio.ApplicationFlags.HANDLES_OPEN,
        )
        self.set_inactivity_timeout(10_000)
        # Ptyxis's desktop actions (New Window, New Tab) arrive as these.
        for name in ("new-window", "new-tab"):
            action = Gio.SimpleAction.new(name, None)
            action.connect("activate", lambda *_: self.launch(GLib.get_home_dir()))
            self.add_action(action)

    def launch(self, cwd):
        self.hold()
        try:
            open_wezterm(cwd)
        finally:
            self.release()

    def do_activate(self):
        self.launch(GLib.get_home_dir())

    def do_open(self, files, n_files, hint):
        for file in files:
            self.launch(directory_for(file))


if __name__ == "__main__":
    sys.exit(Console().run(sys.argv))
