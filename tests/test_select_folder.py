#!/usr/bin/env python3
"""Tests for amberol-deskband folder selector and persistence helper."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Add scripts directory to sys.path
REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import select_folder


class TestSelectFolder(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.config_dir = Path(self.temp_dir.name) / "amberol-deskband"
        self.config_file = self.config_dir / "config.json"
        os.environ["AMBEROL_DESKBAND_NO_LAUNCH"] = "1"

        # Override paths in select_folder module
        select_folder.CONFIG_DIR = self.config_dir
        select_folder.CONFIG_FILE = self.config_file

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_get_persisted_folder_missing_file(self):
        self.assertEqual(select_folder.get_persisted_folder(), "")

    def test_save_and_get_persisted_folder(self):
        test_dir = tempfile.mkdtemp()
        try:
            resolved = str(Path(test_dir).resolve())
            select_folder.save_persisted_folder(test_dir)
            self.assertTrue(self.config_file.is_file())

            data = json.loads(self.config_file.read_text(encoding="utf-8"))
            self.assertEqual(data.get("default_folder"), resolved)

            persisted = select_folder.get_persisted_folder()
            self.assertEqual(persisted, resolved)
        finally:
            os.rmdir(test_dir)

    def test_get_persisted_folder_nonexistent_directory(self):
        nonexistent = "/path/that/does/not/exist/anywhere"
        select_folder.save_persisted_folder(nonexistent)
        self.assertEqual(select_folder.get_persisted_folder(), "")

    def test_open_in_amberol_respects_no_launch(self):
        test_dir = tempfile.mkdtemp()
        try:
            self.assertTrue(select_folder.open_in_amberol(test_dir, play=True))
        finally:
            os.rmdir(test_dir)

    def test_cli_get_and_set(self):
        script_path = SCRIPTS_DIR / "select_folder.py"
        test_dir = tempfile.mkdtemp()
        try:
            resolved = str(Path(test_dir).resolve())
            env = dict(os.environ, XDG_CONFIG_HOME=self.temp_dir.name, AMBEROL_DESKBAND_NO_LAUNCH="1")
            # Run --set
            res_set = subprocess.run(
                [sys.executable, str(script_path), "--set", test_dir],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertEqual(res_set.returncode, 0)
            self.assertIn("SAVED:", res_set.stdout)

            # Run --get
            res_get = subprocess.run(
                [sys.executable, str(script_path), "--get"],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertEqual(res_get.returncode, 0)
            self.assertEqual(res_get.stdout.strip(), resolved)

            # Run --play-default
            res_play = subprocess.run(
                [sys.executable, str(script_path), "--play-default"],
                env=env,
                capture_output=True,
                text=True
            )
            self.assertEqual(res_play.returncode, 0)
            self.assertIn("PLAYING:", res_play.stdout)
        finally:
            os.rmdir(test_dir)


if __name__ == "__main__":
    unittest.main()
