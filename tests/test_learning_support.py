"""Validate glossary references without fixing any published problem's wording."""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def undefined_terms(item, common):
    definitions = set(common) | set(item.get("glossary", {}))
    blocks = [("initial_information", "initial", item["initial"])]
    for resource in item["resources"]:
        blocks.extend(
            [
                (resource["id"], "overview", resource),
                (resource["id"], "result", resource["result"]),
                (resource["id"], "submission", resource.get("submission", {})),
            ]
        )
    return [
        (source, section, term)
        for source, section, block in blocks
        for term in block.get("terms", [])
        if term not in definitions
    ]


class StandardGlossaryTests(unittest.TestCase):
    def test_published_terms_have_definitions(self):
        common = read_json(ROOT / "data/glossary/security.json")["terms"]
        for path in (ROOT / "data/problems").glob("*.json"):
            with self.subTest(problem=path.name):
                self.assertEqual(undefined_terms(read_json(path), common), [])

    def test_terms_are_optional(self):
        item = {"initial": {}, "resources": [{"id": "reference", "result": {}}]}
        self.assertEqual(undefined_terms(item, {}), [])

    def test_local_definitions_and_common_definitions_are_accepted(self):
        item = {
            "initial": {"terms": ["common", "local"]},
            "resources": [],
            "glossary": {"local": {"label": "Local", "description": "Local term"}},
        }
        self.assertEqual(undefined_terms(item, {"common": {}}), [])

    def test_undefined_references_report_each_location(self):
        item = {
            "initial": {"terms": ["missing"]},
            "resources": [
                {
                    "id": "lookup",
                    "terms": ["missing"],
                    "result": {"terms": ["missing"]},
                    "submission": {"terms": ["missing"]},
                }
            ],
        }
        self.assertEqual(
            undefined_terms(item, {}),
            [
                ("initial_information", "initial", "missing"),
                ("lookup", "overview", "missing"),
                ("lookup", "result", "missing"),
                ("lookup", "submission", "missing"),
            ],
        )
        item["glossary"] = {"missing": {"label": "Defined", "description": "Local"}}
        self.assertEqual(undefined_terms(item, {}), [])


if __name__ == "__main__":
    unittest.main()
