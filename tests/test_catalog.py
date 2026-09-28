"""The generated index uses the runtime loader; no second semantic validator."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from build_problem_catalog import build, load_report, cell


class CatalogTests(unittest.TestCase):
    def test_index_matches_published_content(self):
        result, markdown = build()
        report = json.loads(result)
        self.assertEqual(report["total"], 70)
        self.assertEqual(report["by_difficulty"], {"unrated": 70})
        self.assertEqual(markdown, (ROOT / "docs/problem-catalog.md").read_text())
        self.assertEqual(len(report["packs"]), 1)
        for item in report["problems"]:
            raw = json.loads((ROOT / "data" / item["source_path"]).read_text())
            self.assertEqual(item["title"], raw["title"])
            self.assertEqual(item["explanation"], raw["explanation"])
            self.assertEqual(item["ground_truth"], raw["ground_truth"])
        self.assertEqual(
            len([line for line in markdown.splitlines() if line.startswith("| [")]), 70
        )

    def test_standalone_json_and_semantic_failure(self):
        item = json.loads((ROOT / "tests/fixtures/content.json").read_text())[
            "problems"
        ][0]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "problem.json"
            path.write_text(json.dumps(item))
            report = load_report(path)
            self.assertEqual(len(report["problems"]), 1)
            self.assertEqual(report["packs"], [])
            item["required_evidence"] = ["missing-resource"]
            path.write_text(json.dumps(item))
            with self.assertRaises(ValueError):
                load_report(path)

    def test_cli_failures_do_not_write_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            output = base / "index.md"
            output.write_text("existing")
            result = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts/build_problem_catalog.py"),
                    "--source",
                    str(base / "missing.json"),
                    "--markdown-output",
                    str(output),
                ],
                capture_output=True,
                text=True,
                timeout=60,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertTrue(result.stderr)
            self.assertEqual(output.read_text(), "existing")

    def test_markdown_escaping(self):
        self.assertEqual(cell("a|b\nc<d"), "a&#124;b<br>c&lt;d")


if __name__ == "__main__":
    unittest.main()
