"""ネットワークや実際の導入先を使わず、配置と失敗時の保存を検証する。"""

import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from scripts import install_templates as installer


class TemplateInstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.archive = self.root / "templates.tpz"
        self.destination = self.root / "installed/4.7.2.stable"
        with zipfile.ZipFile(self.archive, "w") as bundle:
            bundle.writestr("templates/version.txt", "4.7.2.stable\n")
            for name in installer.REQUIRED:
                bundle.writestr("templates/" + name, b"test fixture")
            bundle.writestr("templates/icudt77l.dat", b"icu fixture")
            bundle.writestr("templates/../../unexpected", b"not selected")
            bundle.writestr("templates/android_release.apk", b"not selected")
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()

    def test_install_only_selected_files(self):
        installer.install_archive(
            self.archive, self.destination, "4.7.2.stable", self.digest
        )
        self.assertTrue(
            installer.is_installed(self.destination, "4.7.2.stable")
        )
        self.assertTrue((self.destination / "icudt77l.dat").exists())
        self.assertFalse((self.root / "unexpected").exists())
        self.assertFalse((self.destination / "android_release.apk").exists())
        self.assertTrue(
            (self.destination / "linux_release.x86_64").stat().st_mode & 0o100
        )

    def test_wrong_hash_leaves_destination_absent(self):
        with self.assertRaises(ValueError):
            installer.install_archive(
                self.archive, self.destination, "4.7.2.stable", "0" * 64
            )
        self.assertFalse(self.destination.exists())

    def test_wrong_version_leaves_destination_absent(self):
        with self.assertRaises(ValueError):
            installer.install_archive(
                self.archive, self.destination, "4.7.1.stable", self.digest
            )
        self.assertFalse(self.destination.exists())

    def test_existing_directory_is_preserved(self):
        self.destination.mkdir(parents=True)
        (self.destination / "existing").write_text("preserve")
        with self.assertRaises(ValueError):
            installer.install_archive(
                self.archive, self.destination, "4.7.2.stable", self.digest
            )
        self.assertEqual(
            (self.destination / "existing").read_text(), "preserve"
        )
        self.assertEqual(
            list(self.destination.iterdir()), [self.destination / "existing"]
        )

    def test_rerun_does_not_access_network(self):
        installer.install_archive(
            self.archive, self.destination, "4.7.2.stable", self.digest
        )
        with (
            patch.object(
                installer,
                "detect_version",
                return_value=("4.7.2.stable", "4.7.2-stable"),
            ),
            patch.object(
                installer, "template_root", return_value=self.destination.parent
            ),
            patch.object(installer, "release_asset") as fetch,
            patch("sys.argv", ["install_templates.py"]),
        ):
            installer.main()
        fetch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
