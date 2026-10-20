#!/usr/bin/env python3
"""Amberol Deskband - Folder Selector & Persistence Helper.

Opens a native GTK 4 folder selection dialog, persists the selected folder
to ~/.config/amberol-deskband/config.json, binds it directly to Amberol via D-Bus,
and enables immediate playback.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import configparser
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "amberol-deskband"
CONFIG_FILE = CONFIG_DIR / "config.json"
PLAYLIST_FILE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "amberol" / "playlists" / "current.pls"


def get_persisted_folder() -> str:
    if CONFIG_FILE.is_file():
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                folder = data.get("default_folder", "")
                if folder and Path(folder).is_dir():
                    return str(Path(folder).resolve())
        except Exception:
            pass
    return ""


def save_persisted_folder(folder_path: str) -> None:
    resolved = str(Path(folder_path).resolve())
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp_file = CONFIG_DIR / ".config.json.tmp"
    data = {"default_folder": resolved}
    tmp_file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp_file.replace(CONFIG_FILE)


def is_amberol_running() -> bool:
    try:
        res = subprocess.run(["busctl", "--user", "status", "io.bassi.Amberol"], capture_output=True)
        if res.returncode == 0:
            return True
    except Exception:
        pass
    try:
        res = subprocess.run(["pgrep", "-x", "amberol"], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False


def playlist_mtime_ns() -> int:
    try:
        return PLAYLIST_FILE.stat().st_mtime_ns
    except OSError:
        return 0


def playlist_contains_folder(folder_path: str) -> bool:
    """Return whether Amberol's saved current queue contains a track in folder."""
    target = Path(folder_path).resolve()
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    try:
        with PLAYLIST_FILE.open(encoding="utf-8") as playlist:
            parser.read_file(playlist)
        section = parser["playlist"]
        count = int(section.get("NumberOfEntries", "0"))
        if count == 0:
            return False
        for index in range(count):
            entry = section.get(f"File{index}")
            if not entry:
                return False
            track = Path(entry).resolve()
            try:
                track.relative_to(target)
            except ValueError:
                return False
        return True
    except (OSError, KeyError, ValueError, configparser.Error):
        return False
    return False


def wait_for_folder_queue(folder_path: str, previous_mtime: int, timeout: float = 60.0) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if playlist_mtime_ns() > previous_mtime and playlist_contains_folder(folder_path):
            # Amberol writes the queue just before selecting its first track.
            time.sleep(0.2)
            return True
        time.sleep(0.1)
    return False


def amberol_has_media() -> bool:
    try:
        res = subprocess.run(
            ["busctl", "--user", "call", "org.mpris.MediaPlayer2.io.bassi.Amberol",
             "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "Get",
             "ss", "org.mpris.MediaPlayer2.Player", "Metadata"],
            capture_output=True, text=True, timeout=1
        )
        return "xesam:title" in res.stdout or "xesam:url" in res.stdout
    except Exception:
        return False


def open_in_amberol(folder_path: str, play: bool = False, wait_for_load: bool = True) -> bool:
    if os.environ.get("AMBEROL_DESKBAND_NO_LAUNCH") == "1":
        return True

    resolved_path = str(Path(folder_path).resolve())
    if not Path(resolved_path).is_dir():
        return False
    uri = Path(resolved_path).as_uri()
    previous_mtime = playlist_mtime_ns()

    running = is_amberol_running()
    if running:
        result = subprocess.run(
            ["busctl", "--user", "call", "io.bassi.Amberol",
             "/io/bassi/Amberol", "org.freedesktop.Application", "Open",
             "asa{sv}", "1", uri, "0"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            print(f"ERROR: Amberol rejected the selected folder: {result.stderr.strip()}", file=sys.stderr)
            return False
    else:
        wrapper = Path.home() / ".local/bin/amberol"
        local_amberol = Path.home() / ".local/lib/amberol-deskband/bin/amberol"
        amberol_bin = str(wrapper) if wrapper.is_file() and os.access(wrapper, os.X_OK) else (
            str(local_amberol) if local_amberol.is_file() and os.access(local_amberol, os.X_OK) else (
            "/usr/bin/amberol" if Path("/usr/bin/amberol").is_file() else "amberol"
            )
        )
        try:
            subprocess.Popen([amberol_bin, resolved_path], start_new_session=True)
        except OSError as err:
            print(f"ERROR: Could not start Amberol: {err}", file=sys.stderr)
            return False

    if wait_for_load or play:
        if not wait_for_folder_queue(resolved_path, previous_mtime):
            print(f"ERROR: Amberol did not load a playlist from {resolved_path}.", file=sys.stderr)
            return False

    if play:
        result = subprocess.run(
            ["busctl", "--user", "call", "org.mpris.MediaPlayer2.io.bassi.Amberol",
             "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Play"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode != 0:
            print(f"ERROR: Amberol loaded the folder but did not start playback: {result.stderr.strip()}", file=sys.stderr)
            return False
    return True


def choose_folder(auto_play: bool = False) -> None:
    try:
        import gi
        gi.require_version("Gtk", "4.0")
        from gi.repository import Gio, GLib, Gtk
    except Exception as e:
        print(f"ERROR: GTK4 not available: {e}", file=sys.stderr)
        sys.exit(1)

    app = Gtk.Application(application_id="io.bassi.AmberolDeskband.FolderChooser")

    def on_select_finish(dialog, result):
        try:
            folder = dialog.select_folder_finish(result)
            if folder:
                path = folder.get_path()
                if path and Path(path).is_dir():
                    save_persisted_folder(path)
                    if not open_in_amberol(path, play=auto_play):
                        return
                    print(f"SELECTED:{path}")
        except GLib.GError:
            print("CANCELLED")
        except Exception as err:
            print(f"ERROR:{err}", file=sys.stderr)
        finally:
            app.release()

    def on_activate(application):
        application.hold()
        dialog = Gtk.FileDialog()
        dialog.set_title("Selecionar Pasta de Músicas")
        dialog.set_accept_label("Selecionar")

        initial = get_persisted_folder()
        if not initial:
            music_dir = Path.home() / "Music"
            if music_dir.is_dir():
                initial = str(music_dir)
        if initial and Path(initial).is_dir():
            dialog.set_initial_folder(Gio.File.new_for_path(initial))

        dialog.select_folder(None, None, on_select_finish)

    app.connect("activate", on_activate)
    app.run([])


def main():
    parser = argparse.ArgumentParser(description="Amberol Deskband folder selector")
    parser.add_argument("--get", action="store_true", help="Print currently persisted default folder")
    parser.add_argument("--set", type=str, metavar="PATH", help="Set default folder directly")
    parser.add_argument("--play-default", action="store_true", help="Launch Amberol with default folder and play")
    parser.add_argument("--ensure-loaded", action="store_true", help="Ensure default folder is loaded if Amberol is running empty")
    parser.add_argument("--play", action="store_true", help="Trigger playback when opening folder")
    parser.add_argument("--no-launch", action="store_true", help="Do not spawn Amberol process")
    args = parser.parse_args()

    if args.no_launch:
        os.environ["AMBEROL_DESKBAND_NO_LAUNCH"] = "1"

    if args.get:
        folder = get_persisted_folder()
        if folder:
            print(folder)
        sys.exit(0)

    if args.set:
        target = Path(args.set).resolve()
        if not target.is_dir():
            print(f"ERROR: Not a directory: {args.set}", file=sys.stderr)
            sys.exit(1)
        save_persisted_folder(str(target))
        if not open_in_amberol(str(target), play=args.play):
            sys.exit(1)
        print(f"SAVED:{target}")
        sys.exit(0)

    if args.play_default:
        folder = get_persisted_folder()
        if folder:
            if not open_in_amberol(folder, play=True):
                sys.exit(1)
            print(f"PLAYING:{folder}")
        sys.exit(0)

    if args.ensure_loaded:
        if is_amberol_running() and not amberol_has_media():
            folder = get_persisted_folder()
            if folder:
                if not open_in_amberol(folder, play=False):
                    sys.exit(1)
                print(f"LOADED:{folder}")
        sys.exit(0)

    choose_folder(auto_play=args.play)


if __name__ == "__main__":
    main()
