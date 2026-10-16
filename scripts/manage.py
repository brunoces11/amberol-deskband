#!/usr/bin/env python3
"""Install owned registration only; preserve symlinks and unrelated settings."""
import argparse
import copy
import fcntl
import json
import os
import re
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile

PLUGIN = "amberol-deskband"
REPOSITORY = Path(__file__).resolve().parents[1]


def identifier(entry):
    return entry if isinstance(entry, str) else entry.get("id") if isinstance(entry, dict) else None


def read_config(path):
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def write_config(path, value):
    # Replace the real file, never the configuration symlink itself.
    target = path.resolve(strict=True)
    mode = stat.S_IMODE(target.stat().st_mode)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=target.parent, prefix=".deskband-", delete=False) as stream:
            temporary = Path(stream.name)
            json.dump(value, stream, indent=2, ensure_ascii=False)
            stream.write("\n")
            stream.flush()
            os.fsync(stream.fileno())
        temporary.chmod(mode)
        os.replace(temporary, target)
        if read_config(path) != value:
            raise RuntimeError(f"Verification failed: {path}")
        print(f"OK: configuration verified: {path.name}")
    finally:
        if temporary and temporary.exists():
            temporary.unlink()


def run(args):
    config_root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "omarchy"
    shell_path = config_root / "shell.json"
    dock_path = config_root / "dock-settings.json"
    link = config_root / "plugins" / PLUGIN
    if not shell_path.is_file():
        raise ValueError("Omarchy shell.json is missing; set up Omarchy Quattro first.")
    shell_before = read_config(shell_path)
    if shell_before.get("version") != 1:
        raise ValueError("Only Omarchy shell.json version 1 is supported.")
    if (link.exists() or link.is_symlink()) and (not link.is_symlink() or link.resolve() != REPOSITORY):
        raise ValueError(f"Refusing to replace an unmanaged path: {link}")
    shell_after = copy.deepcopy(shell_before)
    bar = shell_after.get("bar", {})
    if not isinstance(bar, dict):
        raise ValueError("Invalid bar configuration.")
    layout = bar.get("layout", {})
    if not isinstance(layout, dict):
        raise ValueError("Invalid bar layout.")
    for section in ("left", "center", "right"):
        if not isinstance(layout.get(section, []), list):
            raise ValueError(f"Invalid bar section: {section}")
    plugins = shell_after.get("plugins", [])
    if not isinstance(plugins, list):
        raise ValueError("Invalid plugins list.")
    existing_entry = next((copy.deepcopy(entry) for entries in layout.values() if isinstance(entries, list)
                           for entry in entries if identifier(entry) == PLUGIN), {"id": PLUGIN})
    for section in ("left", "center", "right"):
        if section in layout:
            layout[section] = [entry for entry in layout[section] if identifier(entry) != PLUGIN]
    if "plugins" in shell_after:
        shell_after["plugins"] = [entry for entry in plugins if identifier(entry) != PLUGIN]
    dock_before = read_config(dock_path) if dock_path.is_file() else None
    dock_after = copy.deepcopy(dock_before)
    if dock_after is not None:
        if not isinstance(dock_after.get("dockWidgets", []), list):
            raise ValueError("Invalid dockWidgets list.")
        if "dockWidgets" in dock_after:
            dock_after["dockWidgets"] = [entry for entry in dock_after["dockWidgets"] if entry != PLUGIN]
    installing = args.action == "install"
    if installing:
        for executable in ("quickshell",):
            if not shutil.which(executable):
                raise ValueError(f"Required dependency missing: {executable}")
        version_output = subprocess.check_output(["quickshell", "--version"], text=True, timeout=5)
        version = re.search(r"Quickshell\s+(\d+)\.(\d+)\.(\d+)", version_output)
        if not version or tuple(map(int, version.groups())) < (0, 3, 1):
            raise ValueError("Quickshell 0.3.1 or newer is required; tested with the 0.3 series.")
        if args.target in ("windoc", "both"):
            host = config_root / "plugins" / "rosakodu.dock" / "DockPanel.qml"
            if not host.is_file() or "readonly property int deskbandApiVersion: 1" not in host.read_text():
                raise ValueError("This dock lacks Deskband host API 1. Install the compatible WinDoc integration first.")
            if dock_after is None:
                raise ValueError("WinDoc dock-settings.json is missing.")
            extras = [entry for entry in dock_after.get("dockWidgets", []) if entry not in ("omarchy.menu", "omarchy.apps")]
            if extras:
                raise ValueError("The dock already hosts another extra widget; remove it in the dock settings first.")
            dock_after.setdefault("dockWidgets", []).append(PLUGIN)
            dock_after["widgetsEnabled"] = True
            shell_after.setdefault("plugins", []).append({"id": PLUGIN})
        if args.target in ("top", "both"):
            shell_after.setdefault("bar", {})["layout"] = layout
            layout.setdefault(args.section, []).append(existing_entry)
        if "disabledPlugins" in shell_after:
            shell_after["disabledPlugins"] = [entry for entry in shell_after["disabledPlugins"] if identifier(entry) != PLUGIN]
    plans = [(shell_path, shell_before, shell_after)]
    if dock_before is not None and dock_before != dock_after:
        plans.append((dock_path, dock_before, dock_after))
    if args.check:
        print(f"OK: {args.action} preflight passed for {args.target}; no files changed.")
        return
    changed = []
    created_link = False
    try:
        if installing and not link.is_symlink():
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(REPOSITORY, target_is_directory=True)
            created_link = True
            if not link.is_symlink() or link.resolve() != REPOSITORY:
                raise RuntimeError("Plugin symlink verification failed.")
            print("OK: plugin symlink created and verified.")
        for path, before, after in plans:
            if before != after:
                # Detect edits made since preflight instead of overwriting them.
                if read_config(path) != before:
                    raise RuntimeError(f"Configuration changed concurrently: {path}")
                changed.append((path, before, after))
                write_config(path, after)
        if not installing and link.is_symlink():
            link.unlink()
            if link.is_symlink() or link.exists():
                raise RuntimeError("Unlink verification failed.")
            print("OK: owned plugin symlink removed and verified.")
    except Exception:
        for path, before, after in reversed(changed):
            if read_config(path) == after:
                write_config(path, before)
        if created_link and link.is_symlink() and link.resolve() == REPOSITORY:
            link.unlink()
            if link.is_symlink():
                raise RuntimeError("Rollback unlink verification failed.")
            print("OK: installation symlink rollback verified.")
        raise
    if not args.no_reload and shutil.which("omarchy-shell"):
        result = subprocess.run(["omarchy-shell", "shell", "rescanPlugins"], capture_output=True, text=True, timeout=10)
        if result.returncode:
            print("Configuration verified. Shell rescan unavailable; reload the shell when ready.", file=sys.stderr)
        else:
            print("OK: shell accepted plugin rescan.")
    print(f"OK: {args.action} complete and verified.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("install", "uninstall"))
    target = parser.add_mutually_exclusive_group()
    target.add_argument("--windoc", dest="target", action="store_const", const="windoc")
    target.add_argument("--both", dest="target", action="store_const", const="both")
    target.add_argument("--top", dest="target", action="store_const", const="top")
    parser.set_defaults(target="top")
    parser.add_argument("--section", choices=("left", "center", "right"), default="right")
    parser.add_argument("--check", action="store_true", help="Validate only; do not change files")
    parser.add_argument("--no-reload", action="store_true", help="Do not contact the running shell")
    args = parser.parse_args()
    if args.check:
        run(args)
        return
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", str(Path.home() / ".cache")))
    runtime.mkdir(parents=True, exist_ok=True)
    if not runtime.is_dir():
        raise RuntimeError("Runtime directory verification failed.")
    with (runtime / "amberol-deskband-install.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        run(args)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, json.JSONDecodeError, subprocess.SubprocessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
