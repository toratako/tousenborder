"""Checks for catalog drift and authoring errors that can silently weaken the lessons."""

import copy
import json
from pathlib import Path
from unittest.mock import patch
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from build_problem_catalog import (
    build,
    read_json,
    resource_path,
    validate_authoring,
    validate_pack,
)


class CatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = read_json(ROOT / "tests/fixtures/content.json")
        cls.pack = fixture["pack"]
        cls.cases = fixture["problems"]

    def test_catalog_matches_playable_source(self):
        result, markdown = build(ROOT / "data/packs/learning.json")
        self.assertEqual(
            markdown,
            (ROOT / "docs/problem-catalog.md").read_text(encoding="utf-8"),
        )
        pack = read_json(ROOT / "data/packs/learning.json")
        problems = json.loads(result)["problems"]
        self.assertEqual([p["path"] for p in problems], pack["problems"])
        for p in problems:
            self.assertEqual(p["title"], read_json(resource_path(p["path"]))["title"])
            self.assertTrue(p["main_evidence"])

    def test_missing_evidence_is_rejected(self):
        item = copy.deepcopy(self.cases[0])
        item["required_evidence"] = ["nonexistent_vendor_hash"]
        with self.assertRaisesRegex(ValueError, "missing resources"):
            validate_authoring(item, self.pack)

    def test_very_beginner_allows_reference_evidence_in_any_reference_group(self):
        item = copy.deepcopy(self.cases[0])
        reference = {"id": "policy", "name": "Policy", "content": "Accept PDF documents only."}
        item["references"] = [reference]
        item["required_evidence"] = ["initial_information", "policy"]
        validate_authoring(item, self.pack)
        item["evidence_alternatives"] = {"format_policy": {"label": "Format policy", "any_of": ["policy"]}}
        item["required_evidence"] = ["format_policy"]
        validate_authoring(item, self.pack)
        pack = copy.deepcopy(self.pack)
        pack["resource_groups"].append({"id": "policy_documents", "label": "Policy documents", "kind": "references"})
        item["references"] = []
        item["resources"] = {"policy_documents": [reference]}
        validate_authoring(item, pack)

    def test_very_beginner_rejects_tools_and_external_references_in_any_group(self):
        tool = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-FILE")["tools"][0])
        external = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-PRIVATE-FILE")["external_references"][0])
        external["accepted_information_types"] = ["file"]
        external["input_bindings"] = [{"source": "initial_information", "id": "File名"}]
        for kind, resource in [("tools", tool), ("external_references", external)]:
            for custom in [False, True]:
                with self.subTest(kind=kind, custom=custom):
                    item = copy.deepcopy(self.cases[0])
                    pack = copy.deepcopy(self.pack)
                    if custom:
                        pack["resource_groups"].append({"id": "extra", "label": "Extra", "kind": kind})
                        item["resources"] = {"extra": [resource]}
                    else:
                        item[kind] = [resource]
                    with self.assertRaisesRegex(ValueError, "very_beginner investigations allow only Reference"):
                        validate_authoring(item, pack)

    def test_external_submission_needs_actual_value_and_boolean_usage(self):
        original = next(c for c in self.cases if c["external_references"])
        for key, value in [
            ("submission_value", ""),
            ("correct_usage", "false"),
        ]:
            item = copy.deepcopy(original)
            item["external_references"][0][key] = value
            with self.assertRaises(ValueError):
                validate_authoring(item, self.pack)

    def test_inspired_claim_needs_a_source(self):
        item = copy.deepcopy(
            next(
                c
                for c in self.cases
                if c["scenario_type"] == "real_world_inspired"
            )
        )
        item["sources"] = []
        with self.assertRaises(ValueError):
            validate_authoring(item, self.pack)

    def test_tool_without_input_contract_is_rejected(self):
        item = copy.deepcopy(next(c for c in self.cases if c["tools"]))
        item["tools"][0].pop("input_bindings")
        with self.assertRaises(ValueError):
            validate_authoring(item, self.pack)

    def test_missing_or_wrong_type_input_source_is_rejected(self):
        original = next(
            c for c in self.cases if c["id"] == "FIX-HASH"
        )
        for id in ["missing-field", "Size"]:
            item = copy.deepcopy(original)
            item["tools"][0]["input_bindings"][0]["id"] = id
            with self.assertRaises(ValueError):
                validate_authoring(item, self.pack)

    def test_cycle_cannot_make_unearned_hash_available(self):
        item = copy.deepcopy(
            next(c for c in self.cases if c["id"] == "FIX-HASH")
        )
        sha = next(t for t in item["tools"] if t["id"] == "sha256sum")
        sha["accepted_information_types"] = ["sha256"]
        sha["input_bindings"] = [{"source": "sha256sum", "id": "sha256"}]
        with self.assertRaisesRegex(ValueError, "cyclic safe-input route"):
            validate_authoring(item, self.pack)

    def test_check_detects_drift_without_overwriting(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            args = [
                sys.executable,
                str(ROOT / "scripts/build_problem_catalog.py"),
                "--json-output",
                str(target / "catalog.json"),
                "--markdown-output",
                str(target / "catalog.md"),
            ]
            generated = subprocess.run(args, capture_output=True)
            self.assertEqual(generated.returncode, 0, generated.stderr)
            (target / "catalog.md").write_text(
                "stale catalog", encoding="utf-8"
            )
            checked = subprocess.run(args + ["--check"], capture_output=True)
            self.assertNotEqual(checked.returncode, 0)
            self.assertEqual(
                (target / "catalog.md").read_text(encoding="utf-8"),
                "stale catalog",
            )

    def test_os_restriction_cannot_break_evidence_or_input_chain(self):
        item = copy.deepcopy(
            next(c for c in self.cases if c["id"] == "FIX-DNS")
        )
        item["evidence_alternatives"]["dns_lookup"]["any_of"] = ["dig"]
        validate_authoring(item, self.pack)
        item["evidence_alternatives"]["dns_lookup"]["any_of"] = ["resolve_dnsname"]
        with self.assertRaisesRegex(ValueError, "unavailable on linux"):
            validate_authoring(item, self.pack)
        item = copy.deepcopy(
            next(c for c in self.cases if c["id"] == "FIX-DNS")
        )
        next(t for t in item["tools"] if t["id"] == "url_parse")[
            "environments"
        ] = ["windows"]
        with self.assertRaisesRegex(ValueError, "unreachable inputs on linux"):
            validate_authoring(item, self.pack)

    def test_schema_rejects_unknown_keys_and_legacy_formats(self):
        for field, value in [("day", 1), ("actions", []), ("environment", "windows"),
                             ("provider", "mock"), ("ground_truth", "unknown"),
                             ("platform", "macos"), ("level", "expert"),
                             ("schema_version", True)]:
            with self.subTest(field=field):
                item = copy.deepcopy(self.cases[0])
                item[field] = value
                with self.assertRaisesRegex(ValueError, "schema"):
                    validate_authoring(item, self.pack)
        for field in ["cases", "tools", "require_tool_inputs", "require_evidence", "npcs"]:
            with self.subTest(pack_field=field):
                pack = copy.deepcopy(self.pack)
                pack[field] = []
                with self.assertRaisesRegex(ValueError, "schema"):
                    validate_pack(pack)

    def test_nested_unknown_keys_and_non_https_sources_rejected(self):
        original = next(c for c in self.cases if c["tools"])
        for field, value in [("provider", "mock"), ("legacy_result", {})]:
            item = copy.deepcopy(original)
            item["tools"][0][field] = value
            with self.assertRaisesRegex(ValueError, "schema"):
                validate_authoring(item, self.pack)
        item = copy.deepcopy(original)
        item["sources"] = ["http://example.com/source"]
        with self.assertRaises(ValueError):
            validate_authoring(item, self.pack)

    def test_registry_and_resource_identity_are_enforced(self):
        original = next(c for c in self.cases if c["tools"])
        item = copy.deepcopy(original)
        item["category"] = "unregistered"
        with self.assertRaisesRegex(ValueError, "unregistered category"):
            validate_authoring(item, self.pack)
        item = copy.deepcopy(original)
        item["tools"].append(copy.deepcopy(item["tools"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate resource"):
            validate_authoring(item, self.pack)
        item = copy.deepcopy(original)
        item["resources"] = {"unknown_group": []}
        with self.assertRaisesRegex(ValueError, "unregistered resource group"):
            validate_authoring(item, self.pack)

    def test_check_allows_absent_generated_json(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/build_problem_catalog.py"),
                "--check", "--json-output", str(Path(directory) / "absent.json"),
            ], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_os_output_must_cover_supported_environments(self):
        item = copy.deepcopy(
            next(c for c in self.cases if c["id"] == "FIX-DNS")
        )
        next(t for t in item["tools"] if t["id"] == "nslookup")[
            "output_by_environment"
        ].pop("linux")
        with self.assertRaisesRegex(ValueError, "OS output variant"):
            validate_authoring(item, self.pack)

    def test_unsafe_upload_cannot_be_required_evidence(self):
        item = copy.deepcopy(
            next(c for c in self.cases if c["id"] == "FIX-PRIVATE-FILE")
        )
        item["required_evidence"].append("vt_upload")
        with self.assertRaisesRegex(
            ValueError, "required evidence unavailable"
        ):
            validate_authoring(item, self.pack)

    def test_output_provenance_and_eligibility_are_enforced(self):
        original = next(c for c in self.cases if c["id"] == "FIX-HASH")
        for field, value in [("source", "initial_information"), ("id", "output")]:
            item = copy.deepcopy(original)
            sha = next(t for t in item["tools"] if t["id"] == "sha256sum")
            sha["output_information"][0][field] = value
            with self.assertRaises(ValueError):
                validate_authoring(item, self.pack)
        item = copy.deepcopy(original)
        sha = next(t for t in item["tools"] if t["id"] == "sha256sum")
        sha["output_information"][0]["tool_input"] = False
        with self.assertRaisesRegex(ValueError, "input type mismatch"):
            validate_authoring(item, self.pack)

    def test_custom_group_must_match_registered_kind(self):
        original = next(c for c in self.cases if c["external_references"])
        item = copy.deepcopy(original)
        item["resources"] = {"attachment_tools": [item["external_references"].pop(0)]}
        with self.assertRaisesRegex(ValueError, "resource group attachment_tools schema"):
            validate_authoring(item, self.pack)

    def test_schema_applies_inside_evidence_alternatives(self):
        item = copy.deepcopy(next(c for c in self.cases if c.get("evidence_alternatives")))
        alternative = next(iter(item["evidence_alternatives"].values()))
        alternative["legacy"] = True
        with self.assertRaisesRegex(ValueError, "schema"):
            validate_authoring(item, self.pack)

    def test_unknown_properties_rejected_in_nested_contracts(self):
        original = next(c for c in self.cases if c["tools"])
        item = copy.deepcopy(original)
        item["tools"][0]["input_bindings"][0]["legacy_source"] = "fields"
        with self.assertRaisesRegex(ValueError, "schema"):
            validate_authoring(item, self.pack)
        for field in ["categories", "rules", "resource_groups"]:
            pack = copy.deepcopy(self.pack)
            pack[field][0]["legacy"] = True
            with self.assertRaisesRegex(ValueError, "schema"):
                validate_pack(pack)

    def test_empty_initial_information_and_alternative_keys_rejected(self):
        for key in ["", "   "]:
            item = copy.deepcopy(self.cases[0])
            item["initial_information"][key] = "value"
            with self.assertRaisesRegex(ValueError, "empty initial information key"):
                validate_authoring(item, self.pack)
            item = copy.deepcopy(self.cases[0])
            item["evidence_alternatives"] = {key: {"label": "Invalid key", "any_of": ["initial_information"]}}
            with self.assertRaisesRegex(ValueError, "invalid evidence alternative"):
                validate_authoring(item, self.pack)

    def test_schema_integer_semantics_accepts_integral_number(self):
        item = copy.deepcopy(self.cases[0])
        pack = copy.deepcopy(self.pack)
        item["schema_version"] = 1.0
        pack["schema_version"] = 1.0
        validate_authoring(item, pack)

    def test_permitted_external_results_can_be_required_evidence(self):
        original = next(c for c in self.cases if any(e["correct_usage"] for e in c["external_references"]))
        item = copy.deepcopy(original)
        external = next(e for e in item["external_references"] if e["correct_usage"])
        item["required_evidence"] = [external["id"]]
        validate_authoring(item, self.pack)
        item["evidence_alternatives"] = {"external_only": {"label": "External only", "any_of": [external["id"]]}}
        item["required_evidence"] = ["external_only"]
        validate_authoring(item, self.pack)
        item["evidence_alternatives"]["external_only"]["any_of"].append("initial_information")
        validate_authoring(item, self.pack)

    def test_json_reader_rejects_nonfinite_numbers(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.json"
            for value in ["NaN", "Infinity", "-Infinity", "1e999"]:
                path.write_text('{"value": ' + value + '}', encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "Non-finite JSON number"):
                    read_json(path)

    def test_external_output_unlocks_followup_only_when_permitted(self):
        item = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-HASH"))
        external = item["external_references"][0]
        external["output_information"] = [
            {"id": "domain", "label": "Observed domain", "value": "analysis.example", "data_type": "domain"}
        ]
        followup = copy.deepcopy(external)
        followup.update(id="domain_report", accepted_information_types=["domain"],
                        input_bindings=[{"source": external["id"], "id": "domain"}],
                        submission_type="domain", submission_value="analysis.example", output_information=[])
        item["external_references"].append(followup)
        item["required_evidence"] = [followup["id"]]
        validate_authoring(item, self.pack)
        external["correct_usage"] = False
        with self.assertRaisesRegex(ValueError, "safe-input route"):
            validate_authoring(item, self.pack)
        external["correct_usage"] = True
        external["environments"] = ["windows"]
        with self.assertRaisesRegex(ValueError, "safe-input route"):
            validate_authoring(item, self.pack)

    def test_external_alternatives_do_not_make_unsafe_evidence_required(self):
        item = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-PRIVATE-FILE"))
        item["evidence_alternatives"] = {"report": {"label": "Report", "any_of": ["vt_upload", "vt_hash"]}}
        item["required_evidence"] = ["report"]
        validate_authoring(item, self.pack)
        item["evidence_alternatives"]["report"]["any_of"] = ["vt_upload"]
        with self.assertRaisesRegex(ValueError, "required evidence unavailable"):
            validate_authoring(item, self.pack)

    def test_catalog_includes_tools_that_produce_external_inputs(self):
        item = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-HASH"))
        item["required_evidence"] = ["vt_hash"]
        pack = copy.deepcopy(self.pack)
        pack["problems"] = ["res://data/problems/FIX-HASH.json"]
        pack_path = ROOT / "data/packs/fixture.json"
        def fixture_reader(path):
            if path == pack_path:
                return pack
            if path == resource_path(pack["problems"][0]):
                return item
            return read_json(path)
        with patch("build_problem_catalog.read_json", side_effect=fixture_reader):
            result, markdown = build(pack_path)
        problem = json.loads(result)["problems"][0]
        self.assertEqual(problem["main_tools"], ["sha256sum"])
        self.assertEqual(problem["main_evidence"][0]["any_of"], ["vt_hash"])
        self.assertIn("Main Evidence", markdown)
        self.assertIn("External Reference", markdown)

    def test_correct_usage_requires_explanation(self):
        item = copy.deepcopy(next(c for c in self.cases if c["tools"]))
        item["tools"][0]["correct_usage"] = True
        item["tools"][0].pop("reason", None)
        with self.assertRaisesRegex(ValueError, "reason"):
            validate_authoring(item, self.pack)

    def test_incorrect_usage_output_cannot_unlock_followup(self):
        item = copy.deepcopy(next(c for c in self.cases if c["id"] == "FIX-HASH"))
        tool = next(t for t in item["tools"] if t["id"] == "sha256sum")
        tool.update(correct_usage=False, reason="Unsafe fixture for graph regression")
        with self.assertRaisesRegex(ValueError, "safe-input route"):
            validate_authoring(item, self.pack)

    def test_equivalent_packet_views_agree(self):
        item = next(
            c for c in self.cases if c["id"] == "FIX-PACKETS"
        )
        tcpdump = next(
            t["output"] for t in item["tools"] if t["id"] == "tcpdump"
        )
        wireshark = next(
            t["output"] for t in item["tools"] if t["id"] == "wireshark"
        )
        for value in ["192.0.2.40", "203.0.113.66", "55000", "55001", "8443"]:
            self.assertIn(value, tcpdump)
            self.assertIn(value, wireshark)
        self.assertIn("08:58:00", tcpdump)
        self.assertIn("08:59:00", tcpdump)
        self.assertIn("60.000000", wireshark)


if __name__ == "__main__":
    unittest.main()
