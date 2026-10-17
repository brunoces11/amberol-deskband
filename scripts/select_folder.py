#!/usr/bin/env python3
"""Amberol Deskband - Folder Selector & Persistence Helper.

Opens a native GTK 4 folder selection dialog, persists the selected folder
to ~/.config/amberol-deskband/config.json, and opens it with Amberol.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "amberol-deskband"
CONFIG_FILE = CONFIG_DIR / "config.json"


def get_persisted_folder() -> str:
    if CONFIG_FILE.is_file():
        try:
            data = json.loads(CONFIG_FILE.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                folder = data.get("default_folder", "")
                if folder and Path(folder).is_dir():
                    return folder
        except Exception:
            pass
    return ""


def save_persisted_folder(folder_path: str) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    tmp_file = CONFIG_DIR / ".config.json.tmp"
    data = {"default_folder": folder_path}
    tmp_file.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    tmp_file.replace(CONFIG_FILE)


def open_in_amberol(folder_path: str) -> None:
    if os.environ.get("AMBEROL_DESKBAND_NO_LAUNCH") == "1":
        return
    amberol_bin = "/usr/bin/amberol" if Path("/usr/bin/amberol").is_file() else "amberol"
    subprocess.Popen([amberol_bin, folder_path], start_new_session=True)


def choose_folder() -> None:
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
                    open_in_amberol(path)
                    print(f"SELECTED:{path}")
        except GLib.GError as err:
            # User cancellation or dialog dismiss
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
    parser.add_argument("--play-default", action="store_true", help="Launch Amberol with default folder if not running")
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
        open_in_amberol(str(target))
        print(f"SAVED:{target}")
        sys.exit(0)

    if args.play_default:
        folder = get_persisted_folder()
        if folder:
            res = subprocess.run(["pgrep", "-f", "amberol"], capture_output=True)
            if res.returncode != 0:
                open_in_amberol(folder)
        sys.exit(0)

    choose_folder()


if __name__ == "__main__":
    main()
