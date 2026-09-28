"""Cross-check the shipped schema vocabulary with a standard JSON Schema engine."""

import json
from pathlib import Path
import unittest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return json.loads(path.read_text())


class ContentSchemaTests(unittest.TestCase):
    def test_all_definitions_conform(self):
        schemas = {}
        for path in (ROOT / "data/schemas").glob("*.schema.json"):
            value = read(path)
            Draft202012Validator.check_schema(value)
            schemas[path.name.removesuffix(".schema.json")] = Draft202012Validator(
                value
            )
        files = list((ROOT / "data/problems").glob("*.json")) + list(
            (ROOT / "authoring/archive/problems").glob("*.json")
        )
        self.assertEqual(len(files), 109)
        for path in files:
            with self.subTest(path=path.name):
                item = read(path)
                schemas["problem"].validate(item)
                self.assertNotIn("rdap", [r["id"] for r in item["resources"]])
        for item in read(ROOT / "tests/fixtures/content.json")["problems"]:
            schemas["problem"].validate(item)
        schemas["problem"].validate(
            read(ROOT / "tests/fixtures/learning-support/problem.json")
        )
        for path in (ROOT / "data/packs").rglob("*.json"):
            schemas["pack" if path.name == "pack.json" else "chapter"].validate(
                read(path)
            )
        schemas["glossary"].validate(read(ROOT / "data/glossary/security.json"))

    def test_equivalent_packet_views_agree(self):
        item = next(
            p
            for p in read(ROOT / "tests/fixtures/content.json")["problems"]
            if p["id"] == "FIX-PACKETS"
        )
        outputs = {r["id"]: r["result"]["content"] for r in item["resources"]}
        for value in ["192.0.2.40", "203.0.113.66", "55000", "55001", "8443"]:
            self.assertIn(value, outputs["tcpdump"])
            self.assertIn(value, outputs["wireshark"])
        self.assertIn("08:58:00", outputs["tcpdump"])
        self.assertIn("08:59:00", outputs["tcpdump"])
        self.assertIn("60.000000", outputs["wireshark"])


if __name__ == "__main__":
    unittest.main()
