"""Exercise reversible installer behavior against isolated configuration trees."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = "amberol-deskband"


class InstallationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="deskband-install-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / "config" / "omarchy"
        self.config.mkdir(parents=True)
        self.shell = self.config / "shell.json"
        self.real_shell = self.root / "managed-shell.json"
        self.before = {"version": 1, "bar": {"layout": {"left": ["omarchy.menu"], "center": [], "right": [{"id": "omarchy.clock", "custom": 5}]}}, "plugins": [{"id": "rosakodu.dock"}], "custom": {"preserve": True}}
        self.real_shell.write_text(json.dumps(self.before))
        self.shell.symlink_to(self.real_shell)
        self.dock = self.config / "dock-settings.json"
        self.dock.write_text(json.dumps({"dockWidgets": ["omarchy.menu", "omarchy.apps"], "systemTray": {"pinnedWidgets": ["omarchy.network"]}}))
        host = self.config / "plugins" / "rosakodu.dock"
        host.mkdir(parents=True)
        (host / "DockPanel.qml").write_text("readonly property int deskbandApiVersion: 1")
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / "config"), XDG_RUNTIME_DIR=str(self.root / "runtime"))

    def invoke(self, action="install", *args, success=True):
        result = subprocess.run(["python3", str(ROOT / "scripts/manage.py"), action, "--no-reload", *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        return result

    def test_windoc_repeat_and_remove_preserves_other_settings(self):
        self.invoke("install", "--windoc")
        self.invoke("install", "--windoc")
        self.assertTrue(self.shell.is_symlink())
        dock = json.loads(self.dock.read_text())
        self.assertEqual(dock["dockWidgets"].count(PLUGIN), 1)
        self.assertEqual(dock["systemTray"]["pinnedWidgets"], ["omarchy.network"])
        current = json.loads(self.shell.read_text())
        current["later_user_edit"] = 123
        self.real_shell.write_text(json.dumps(current))
        self.invoke("uninstall")
        self.invoke("uninstall")
        after = json.loads(self.shell.read_text())
        self.assertEqual(after["later_user_edit"], 123)
        self.assertEqual(after["bar"], self.before["bar"])
        self.assertEqual(after["plugins"], self.before["plugins"])
        self.assertFalse((self.config / "plugins" / PLUGIN).is_symlink())
        self.assertNotIn(PLUGIN, json.loads(self.dock.read_text())["dockWidgets"])

    def test_uninstall_before_install_does_not_expand_minimal_config(self):
        minimal = {"version": 1, "custom": 42}
        self.real_shell.write_text(json.dumps(minimal))
        self.dock.write_text(json.dumps({"custom": "preserve"}))
        self.invoke("uninstall")
        self.assertEqual(json.loads(self.shell.read_text()), minimal)
        self.assertEqual(json.loads(self.dock.read_text()), {"custom": "preserve"})

    def test_conflicting_path_is_not_overwritten(self):
        collision = self.config / "plugins" / PLUGIN
        collision.mkdir()
        self.invoke("install", "--windoc", success=False)
        self.assertEqual(json.loads(self.shell.read_text()), self.before)
        self.assertTrue(collision.is_dir())

    def test_unsupported_host_changes_nothing(self):
        (self.config / "plugins" / "rosakodu.dock" / "DockPanel.qml").write_text("old host")
        self.invoke("install", "--windoc", success=False)
        self.assertEqual(json.loads(self.shell.read_text()), self.before)
        self.assertFalse((self.config / "plugins" / PLUGIN).exists())

    def test_invalid_json_changes_nothing(self):
        before = self.shell.read_bytes()
        self.dock.write_text("{bad JSON")
        self.invoke("install", "--windoc", success=False)
        self.assertEqual(self.shell.read_bytes(), before)

    def test_top_settings_survive_move(self):
        data = json.loads(self.shell.read_text())
        data["bar"]["layout"]["left"].append({"id": PLUGIN, "width": 310, "fallback": False})
        self.real_shell.write_text(json.dumps(data))
        self.invoke("install", "--top", "--section", "center")
        after = json.loads(self.shell.read_text())
        self.assertIn({"id": PLUGIN, "width": 310, "fallback": False}, after["bar"]["layout"]["center"])
        self.assertNotIn(PLUGIN, [entry if isinstance(entry, str) else entry["id"] for entry in after["bar"]["layout"]["left"]])

    def test_check_has_no_configuration_side_effects(self):
        self.invoke("install", "--windoc", "--check")
        self.assertEqual(json.loads(self.shell.read_text()), self.before)
        self.assertFalse((self.config / "plugins" / PLUGIN).exists())
        self.assertFalse((self.root / "runtime").exists())


if __name__ == "__main__":
    unittest.main()
