"""Audit the frozen migration history without freezing today's published content."""

from collections import Counter
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "1f66d2fe5301db9be7bab108a642b1f706cdccd4"
LEVELS = {
    "very_beginner": "very_beginner",
    "beginner_reference": "beginner",
    "beginner": "beginner",
    "beginner_external": "beginner",
    "applied": "applied",
}


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


class DifficultyHistoryTests(unittest.TestCase):
    def setUp(self):
        self.history = read(ROOT / "tests/fixtures/difficulty-history.json")
        self.assertEqual(self.history["source_commit"], COMMIT)

    def test_historical_level_mapping(self):
        historical = self.history["levels"]
        self.assertEqual(len(historical), 70)
        self.assertEqual(
            Counter(LEVELS[level] for level in historical.values()),
            {"very_beginner": 8, "beginner": 51, "applied": 11},
        )

    def test_published_ids_are_unique_and_not_archived(self):
        problems = [read(path) for path in (ROOT / "data/problems").glob("*.json")]
        self.assertEqual(len(problems), len({item["id"] for item in problems}))
        archived = {
            read(path)["id"] for path in (ROOT / "authoring/archive/problems").glob("*.json")
        }
        self.assertFalse(archived & {item["id"] for item in problems})

    def test_history_fixture_matches_git_when_available(self):
        # Shallow CI checkouts still validate the frozen migration mapping.
        if not shutil.which("git"):
            self.skipTest("Git is unavailable; using the committed history extract")
        command = ["git", "-c", f"safe.directory={ROOT}", "-C", str(ROOT)]
        available = subprocess.run(
            command + ["cat-file", "-e", f"{COMMIT}^{{commit}}"],
            capture_output=True,
            timeout=10,
        )
        if available.returncode:
            self.skipTest("Source commit is unavailable in this checkout")
        data = subprocess.check_output(
            command + ["archive", COMMIT, "data/problems"], timeout=30
        )
        levels = {}
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            for entry in archive:
                if entry.isfile() and entry.name.endswith(".json"):
                    item = json.load(archive.extractfile(entry))
                    self.assertNotIn(item["id"], levels)
                    levels[item["id"]] = item["level"]
        for identifier, level in self.history["levels"].items():
            with self.subTest(id=identifier):
                self.assertEqual(levels[identifier], level)


if __name__ == "__main__":
    unittest.main()
