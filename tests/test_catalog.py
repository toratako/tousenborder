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
    validate_review,
    validate_schema,
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
            source = read_json(resource_path(p["path"]))
            self.assertEqual(p["title"], source["title"])
            self.assertEqual(p["initial_information"], source["initial_information"])
            self.assertEqual(p["reason"], source["explanation"])
            self.assertEqual(p["learning_objectives"], source["learning_objectives"])
            self.assertTrue(p["main_evidence"])
            self.assertTrue(p["overview"])
            self.assertTrue(p["expected_investigation_flow"])
            self.assertNotEqual(p["decisive_evidence"], "未レビュー")
            self.assertEqual(
                len(p["available_investigation"]),
                len(validate_authoring(source, pack)),
            )
        table_rows = [line for line in markdown.splitlines() if line.startswith("| [")]
        self.assertEqual(len(table_rows), len(problems))
        self.assertTrue(all(len(line.split("|")) == 17 for line in table_rows))
        for heading in ["Overview", "Initial Information", "Available Investigation",
                        "Expected Investigation Flow", "Decisive Evidence", "Correct Answer",
                        "Reason", "Learning Objective", "Real-world Inspiration"]:
            self.assertIn(heading, markdown)

    def test_applied_selection_excludes_non_attack_cases(self):
        pack = read_json(ROOT / "data/packs/learning.json")
        cases = [read_json(resource_path(path)) for path in pack["problems"]]
        self.assertFalse(any(p["level"] in ("intermediate", "advanced") for p in cases))
        applied = [p for p in cases if p["level"] == "applied"]
        self.assertEqual(len(applied), 11)
        excluded = read_json(ROOT / "data/catalog/excluded.json")["reviews"]
        self.assertEqual(len(excluded), 39)
        self.assertTrue(set(excluded).isdisjoint(p["id"] for p in cases))
        for item in applied:
            self.assertEqual(item["scenario_type"], "real_world_inspired")
            for field, invalid in [("scenario_type", "standard"), ("inspired_by", ""), ("sources", [])]:
                invalid_item = copy.deepcopy(item)
                invalid_item[field] = invalid
                with self.subTest(problem=item["id"], field=field), self.assertRaises(ValueError):
                    validate_authoring(invalid_item, pack)

    def test_rdap_queries_bind_the_actual_ip_or_registered_domain(self):
        pack = read_json(ROOT / "data/packs/learning.json")
        reviews = read_json(ROOT / "data/catalog/learning.json")["reviews"]
        found = []
        for path in pack["problems"]:
            item = read_json(resource_path(path))
            entries = [(kind, r) for kind in ("tools", "references", "external_references") for r in item[kind]]
            for kind, r in entries:
                if r["id"] != "rdap":
                    continue
                found.append(item["id"])
                with self.subTest(problem=item["id"]):
                    self.assertEqual(kind, "external_references")
                    self.assertIn(r["submission_type"], ("ip", "domain"))
                    self.assertEqual(r["accepted_information_types"], [r["submission_type"]])
                    facts = {("initial_information", key): value for key, value in item["initial_information"].items()}
                    facts.update({(entry["id"], info["id"]): info["value"]
                                  for _, entry in entries for info in entry.get("output_information", [])})
                    for binding in r["input_bindings"]:
                        self.assertEqual(facts[(binding["source"], binding["id"])], r["submission_value"])
                    self.assertIn(r["submission_value"], r["output"])
                    flow = [s["resource_id"] for s in reviews[item["id"]]["flow"]]
                    if "rdap" in flow:
                        self.assertLess(flow.index("disclosure"), flow.index("rdap"))
                    if "rdap" in item["required_evidence"]:
                        self.assertIn("disclosure", item["required_evidence"])
        self.assertTrue(found)

    def test_review_flow_requires_inputs_before_dependent_investigation(self):
        item = read_json(ROOT / "data/problems/PROC-WIN-DLL-SIDELOAD.json")
        pack = read_json(ROOT / "data/packs/learning.json")
        entries = validate_authoring(item, pack)
        review = copy.deepcopy(read_json(ROOT / "data/catalog/learning.json")["reviews"][item["id"]])
        validate_review(item, entries, review)
        review["flow"][0], review["flow"][1] = review["flow"][1], review["flow"][0]
        with self.assertRaisesRegex(ValueError, "before its input is available"):
            validate_review(item, entries, review)

    def test_review_flow_accepts_alternatives_but_requires_all_evidence(self):
        item = read_json(ROOT / "data/problems/WEB-UNKNOWN-CAMPAIGN.json")
        pack = read_json(ROOT / "data/packs/learning.json")
        entries = validate_authoring(item, pack)
        review = copy.deepcopy(read_json(ROOT / "data/catalog/excluded.json")["reviews"][item["id"]])
        review["flow"][0]["resource_id"] = "nslookup"
        validate_review(item, entries, review)
        review["flow"] = [step for step in review["flow"] if step["resource_id"] != "official"]
        with self.assertRaisesRegex(ValueError, "omits required evidence official"):
            validate_review(item, entries, review)

    def test_review_flow_rejects_unsafe_or_unavailable_investigation(self):
        pack = read_json(ROOT / "data/packs/learning.json")
        reviews = read_json(ROOT / "data/catalog/learning.json")["reviews"]
        reviews.update(read_json(ROOT / "data/catalog/excluded.json")["reviews"])
        for problem_id, resource in [("FILE-WIN-UNSIGNED-INTERNAL", "file_rep"),
                                     ("WEB-LINUX-DNS", "dig")]:
            with self.subTest(problem=problem_id):
                item = read_json(ROOT / f"data/problems/{problem_id}.json")
                entries = validate_authoring(item, pack)
                review = copy.deepcopy(reviews[problem_id])
                if resource == "dig":
                    next(entry for _, entry in entries if entry["id"] == resource)["environments"] = ["windows"]
                else:
                    review["flow"].append({"resource_id": resource, "action": "Unsafe test"})
                with self.assertRaisesRegex(ValueError, "unsafe or unavailable"):
                    validate_review(item, entries, review)

    def test_review_flow_rejects_unknown_resources(self):
        item = self.cases[0]
        with self.assertRaisesRegex(ValueError, "missing resource"):
            validate_review(item, validate_authoring(item, self.pack), {
                "flow": [{"resource_id": "missing", "action": "Inspect missing resource"}],
            })

    def test_review_schema_rejects_incomplete_or_unknown_fields(self):
        original = read_json(ROOT / "data/catalog/learning.json")
        for field, value in [("overview", " "), ("flow", []), ("decisive_evidence", ""),
                             ("unexpected", "test"), ("flow", [{"resource_id": "initial_information"}])]:
            with self.subTest(field=field, value=value):
                data = copy.deepcopy(original)
                next(iter(data["reviews"].values()))[field] = value
                with self.assertRaisesRegex(ValueError, "catalog-review schema"):
                    validate_schema(data, "catalog-review")

    def test_review_ids_and_pack_must_match_registration(self):
        path = ROOT / "data/catalog/learning.json"
        for change, message in [("missing", "Missing catalog review"),
                                ("extra", "unregistered problems"),
                                ("pack", "content_pack mismatch")]:
            with self.subTest(change=change):
                data = copy.deepcopy(read_json(path))
                if change == "missing":
                    data["reviews"].pop(next(iter(data["reviews"])))
                elif change == "extra":
                    data["reviews"]["NOT-IN-PACK"] = copy.deepcopy(next(iter(data["reviews"].values())))
                else:
                    data["content_pack"] = "res://data/packs/other.json"
                def reader(candidate):
                    return data if candidate == path else read_json(candidate)
                with patch("build_problem_catalog.read_json", side_effect=reader):
                    with self.assertRaisesRegex(ValueError, message):
                        build(ROOT / "data/packs/learning.json")

    def test_review_text_regenerates_and_markdown_preserves_literal_content(self):
        source_path = ROOT / "data/problems/FILE-LINUX-KNOWN-HASH.json"
        review_path = ROOT / "data/catalog/learning.json"
        item = copy.deepcopy(read_json(source_path))
        unsafe = copy.deepcopy(item["external_references"][0])
        unsafe.update(id="unsafe_render_example", correct_usage=False, reason="送信不可の資料")
        item["external_references"].append(unsafe)
        value = 'C:\\Temp\\_literal_ | <TRAINING-PLACEHOLDER>\n**text** [link](target)'
        item["initial_information"]["Render check"] = value
        reviews = copy.deepcopy(read_json(review_path))
        reviews["reviews"][item["id"]]["overview"] = "Changed review overview"
        reviews["reviews"][item["id"]]["review_notes"] = "Review note for rendering test"
        def reader(path):
            if path == source_path:
                return item
            if path == review_path:
                return reviews
            return read_json(path)
        with patch("build_problem_catalog.read_json", side_effect=reader):
            generated, markdown = build(ROOT / "data/packs/learning.json")
        row = next(p for p in json.loads(generated)["problems"] if p["id"] == item["id"])
        self.assertEqual(row["initial_information"]["Render check"], value)
        self.assertEqual(row["overview"], "Changed review overview")
        self.assertEqual(row["review_notes"], "Review note for rendering test")
        self.assertIn("Changed review overview", markdown)
        self.assertIn("Review note for rendering test", markdown)
        self.assertIn("&lt;TRAINING-PLACEHOLDER&gt;<br>", markdown)
        self.assertIn("C:&#92;Temp&#92;&#95;literal&#95; &#124;", markdown)
        self.assertIn("&#42;&#42;text&#42;&#42; &#91;link&#93;(target)", markdown)
        self.assertIn("利用不適切", markdown)
        self.assertIn("設計レビュー注記", markdown)

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

    def test_beginner_classes_follow_resource_kinds_including_custom_groups(self):
        examples = {
            "beginner_reference": "PKG-NPM-LOCKED-DEPENDENCY",
            "beginner": "FILE-LINUX-ELF-AS-DOCUMENT",
            "beginner_external": "FILE-LINUX-KNOWN-HASH",
        }
        for expected, problem_id in examples.items():
            for custom in (False, True):
                item = read_json(ROOT / f"data/problems/{problem_id}.json")
                pack = read_json(ROOT / "data/packs/learning.json")
                if custom:
                    item["resources"] = {}
                    for kind in ("tools", "references", "external_references"):
                        group = f"extra_{kind}"
                        pack["resource_groups"].append({"id": group, "label": group, "kind": kind})
                        item["resources"][group] = item[kind]
                        item[kind] = []
                for level in examples:
                    with self.subTest(expected=expected, level=level, custom=custom):
                        item["level"] = level
                        if level == expected:
                            validate_authoring(item, pack)
                        else:
                            with self.assertRaisesRegex(ValueError, "beginner"):
                                validate_authoring(item, pack)
        empty = copy.deepcopy(self.cases[0])
        empty["level"] = "beginner_reference"
        with self.assertRaisesRegex(ValueError, "Reference resources only"):
            validate_authoring(empty, self.pack)

    def test_beginner_walkthrough_uses_one_of_the_alternative_tools(self):
        item = read_json(ROOT / "data/problems/WEB-WIN-DNS.json")
        pack = read_json(ROOT / "data/packs/learning.json")
        entries = validate_authoring(item, pack)
        original = read_json(ROOT / "data/catalog/learning.json")["reviews"][item["id"]]
        for tool in item["tools"]:
            review = copy.deepcopy(original)
            review["flow"][0]["resource_id"] = tool["id"]
            validate_review(item, entries, review)
        review = copy.deepcopy(original)
        review["flow"].insert(0, {"resource_id": "resolve", "check": "追加のDNS照会"})
        with self.assertRaisesRegex(ValueError, "exactly one Tool"):
            validate_review(item, entries, review)
        review["flow"] = [step for step in original["flow"] if step["resource_id"] == "official"]
        with self.assertRaisesRegex(ValueError, "exactly one Tool"):
            validate_review(item, entries, review)

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
