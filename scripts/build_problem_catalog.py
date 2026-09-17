"""Validate the canonical content schemas and semantics, then generate the catalog."""
from __future__ import annotations

import argparse
from collections import Counter
from functools import lru_cache
import json
import math
from pathlib import Path
import sys

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
LEVEL_LABELS = {
    "very_beginner": "超初級", "beginner": "初級", "intermediate": "中級", "advanced": "上級",
}
GROUP_KINDS = {"tools": "tools", "references": "references", "external_references": "external_references"}

@lru_cache(maxsize=2)
def schema_validator(name: str) -> Draft202012Validator:
    schema = read_json(ROOT / f"data/schemas/{name}.schema.json")
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=FormatChecker())


def validate_schema(value: dict, name: str) -> None:
    errors = sorted(
        schema_validator(name).iter_errors(value),
        key=lambda error: str(list(error.absolute_path)),
    )
    if errors:
        error = errors[0]
        location = ".".join(str(part) for part in error.absolute_path) or "<root>"
        raise ValueError(f"{name} schema at {location}: {error.message}")


def validate_pack(pack: dict) -> None:
    validate_schema(pack, "pack")
    for name in ("categories", "rules", "resource_groups"):
        ids = [entry["id"] for entry in pack.get(name, [])]
        if len(ids) != len(set(ids)):
            raise ValueError(f"Duplicate {name} ID")
    for group in pack.get("resource_groups", []):
        if group["id"] in GROUP_KINDS and group["kind"] != GROUP_KINDS[group["id"]]:
            raise ValueError("Built-in resource group kind cannot be changed")
        if group["id"] == "initial_information":
            raise ValueError("Reserved resource group ID")


def validate_inputs(item: dict, entries: list[tuple[str, dict]]) -> None:
    if any(not key.strip() for key in item["initial_information"]):
        raise ValueError(f"{item['id']}: empty initial information key")
    types = item["initial_information_types"]
    if not set(types) <= item["initial_information"].keys():
        raise ValueError(f"{item['id']}: invalid initial_information_types")
    initial = {("initial_information", key) for key in item["initial_information"]}
    facts = {key: types.get(key[1], "text") for key in initial}
    for _, entry in entries:
        environments = entry.get("environments", [])
        variants = entry.get("output_by_environment")
        if variants is not None and set(variants) != set(environments):
            raise ValueError(f"{item['id']}: missing OS output variant")
        seen = set()
        for output in entry.get("output_information", []):
            if output["id"] in seen or output["id"] in ["output", "content", "submission_type", "submission_value", "warning"]:
                raise ValueError(f"{item['id']}: duplicate/reserved output id")
            seen.add(output["id"])
            facts[(entry["id"], output["id"])] = output["data_type"] if output.get("tool_input", True) else None
    for _, entry in entries:
        for binding in entry.get("input_bindings", []):
            key = binding["source"], binding["id"]
            if key not in facts:
                raise ValueError(f"{item['id']}: missing input source {key}")
            if facts[key] not in entry["accepted_information_types"]:
                raise ValueError(f"{item['id']}: input type mismatch {key}")
    for os in (["windows", "linux"] if item["platform"] == "common" else [item["platform"]]):
        available = {"initial_information"}
        obtained = set(initial)
        pending = [(kind, e) for kind, e in entries if not e.get("environments") or os in e["environments"]]
        while pending:
            ready = [(kind, e) for kind, e in pending if not e.get("input_bindings") or any(
                (b["source"], b["id"]) in obtained for b in e["input_bindings"]
            )]
            if not ready:
                raise ValueError(f"{item['id']}: unreachable inputs on {os} (missing or cyclic safe-input route)")
            for kind, entry in ready:
                if kind != "external_references" and entry.get("correct_usage", True):
                    available.add(entry["id"])
                    obtained.update((entry["id"], o["id"]) for o in entry.get("output_information", []) if o.get("tool_input", True))
                pending.remove((kind, entry))
        for key in item["required_evidence"]:
            options = item.get("evidence_alternatives", {}).get(key, {}).get("any_of", [key])
            if not available.intersection(options):
                raise ValueError(f"{item['id']}: required evidence unavailable on {os} without external references: {key}")


def read_json(path: Path):
    def finite_number(raw: str) -> float:
        value = float(raw)
        if not math.isfinite(value):
            raise ValueError(f"Non-finite JSON number in {path}: {raw}")
        return value

    return json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=finite_number, parse_float=finite_number)


def resource_path(value: str) -> Path:
    if not isinstance(value, str) or not value.startswith("res://"):
        raise ValueError(f"Expected a res:// resource path: {value!r}")
    path = (ROOT / value[6:]).resolve()
    if not path.is_relative_to(ROOT):
        raise ValueError(f"Resource outside project: {value}")
    return path


def validate_authoring(item: dict, pack: dict) -> list[tuple[str, dict]]:
    """Reject invalid authoring data before building runtime-relevant contracts."""
    validate_pack(pack)
    validate_schema(item, "problem")
    if item["category"] not in {entry["id"] for entry in pack["categories"]}:
        raise ValueError(f"{item['id']}: unregistered category")
    groups = dict(GROUP_KINDS)
    for group in pack.get("resource_groups", []):
        groups[group["id"]] = group["kind"]
    for group in item.get("resources", {}):
        if group not in groups or group in GROUP_KINDS:
            raise ValueError(f"{item['id']}: unregistered resource group {group}")
    entries = []
    ids = {"initial_information"}
    for group, kind in groups.items():
        data = item if group in GROUP_KINDS else item.get("resources", {})
        values = data.get(group, [])
        for entry in values:
            validator = schema_validator("problem")
            definition = {"tools": "tool", "references": "reference", "external_references": "external"}[kind]
            error = next(validator.descend(entry, validator.schema["$defs"][definition]), None)
            if error:
                raise ValueError(f"{item['id']}: resource group {group} schema: {error.message}")
            if entry["id"] in ids:
                raise ValueError(f"{item['id']}: duplicate resource {entry['id']}")
            ids.add(entry["id"])
            entries.append((kind, entry))
    alternatives = item.get("evidence_alternatives", {})
    for key, value in alternatives.items():
        if not key.strip() or key in ids or not set(value["any_of"]) <= ids:
            raise ValueError(f"{item['id']}: invalid evidence alternative")
    if not set(item["required_evidence"]) <= ids | set(alternatives):
        raise ValueError(f"{item['id']}: required_evidence refers to missing resources")
    if item["level"] == "very_beginner" and (entries or item["required_evidence"] != ["initial_information"]):
        raise ValueError(f"{item['id']}: very_beginner must be solvable from initial information")
    validate_inputs(item, entries)
    return entries


def build(pack_path: Path) -> tuple[str, str]:
    pack = read_json(pack_path)
    problems = []
    seen = set()
    validate_pack(pack)
    for value in pack["problems"]:
        item = read_json(resource_path(value))
        entries = validate_authoring(item, pack)
        if item["id"] in seen:
            raise ValueError("Duplicate problem ID: " + item["id"])
        seen.add(item["id"])
        problem = {key: item[key] for key in [
            "id", "category", "platform", "level", "ground_truth", "topic", "summary",
            "scenario_type", "decision_context", "learning_objectives", "required_evidence", "sources",
        ]}
        problem.update(path=value, ecosystem=item.get("ecosystem", ""), inspired_by=item.get("inspired_by", ""))
        problem["evidence_alternatives"] = item.get("evidence_alternatives", {})
        for kind in GROUP_KINDS:
            problem[kind] = [entry["name"] for entry_kind, entry in entries if entry_kind == kind]
        problem["investigation_inputs"] = [
            {"resource_id": entry["id"], "name": entry["name"], "input_hint": entry.get("input_hint", ""),
             "accepted_information_types": entry.get("accepted_information_types", []),
             "environments": entry.get("environments", []),
             "input_bindings": entry.get("input_bindings", [])}
            for kind, entry in entries if kind != "references"
        ]
        problems.append(problem)
    total = len(problems)
    if total == 0:
        raise ValueError("The content pack contains no problems")
    inspired = sum(p["scenario_type"] == "real_world_inspired" for p in problems)
    result = {
        "schema_version": 1, "content_pack": "res://" + pack_path.relative_to(ROOT).as_posix(),
        "total": total, "by_category": dict(Counter(p["category"] for p in problems)),
        "by_level": dict(Counter(p["level"] for p in problems)),
        "by_verdict": dict(Counter(p["ground_truth"] for p in problems)),
        "real_world_inspired": inspired, "problems": problems,
    }
    lines = [
        "# Problem Catalog", "",
        f"対象: {result['content_pack']}。実装済み{total}問。"
        f"許可{result['by_verdict'].get('allow', 0)}問・遮断{result['by_verdict'].get('block', 0)}問。"
        f"Real-world inspired {inspired}問（{inspired / total:.1%}）。",
        "", "この一覧には正解が含まれます。"
        "問題JSONを編集し、python scripts/build_problem_catalog.py で再生成してください。"
        "検証のみの場合は --check を指定します。",
        "", "| ID | 種別 | OS / Ecosystem | Level | 正解 | 主題 | 使用Tool（必要な入力） | Reference / External Reference | 実例 | 短い内容説明 |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    def cell(value):
        return str(value).replace("|", r"\|").replace("\n", " ")
    for p in problems:
        link = "../" + p["path"][6:]
        values = [
            f"[{p['id']}]({link})", p["category"], p["platform"] + (f" / {p['ecosystem']}" if p["ecosystem"] else ""),
            LEVEL_LABELS.get(p["level"], p["level"]), p["ground_truth"], p["topic"],
            "、".join(t["name"] + (" ← " + t["input_hint"] if t["input_hint"] else "") for t in p["investigation_inputs"]) or "初期情報／Reference", "、".join(p["references"] + p["external_references"]) or "—",
            p["inspired_by"] or "—", p["summary"],
        ]
        lines.append("| " + " | ".join(cell(v) for v in values) + " |")
    lines += ["", "実例の出典は各問題JSONの sources、仕様と教材上の省略は [設計・教材の方針](learning-design.md) を参照してください。", ""]
    return json.dumps(result, ensure_ascii=False, indent=2) + "\n", "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Validate sources and committed Markdown; check generated JSON when present")
    parser.add_argument("--pack", type=Path, default=ROOT / "data/packs/learning.json")
    parser.add_argument("--json-output", type=Path, default=ROOT / "build/catalog/problems.json")
    parser.add_argument("--markdown-output", type=Path, default=ROOT / "docs/problem-catalog.md")
    args = parser.parse_args()
    try:
        outputs = build(args.pack.resolve())
        for index, (path, content) in enumerate(zip([args.json_output, args.markdown_output], outputs)):
            if args.check:
                if index == 0 and not path.exists():
                    continue
                if not path.exists() or path.read_text(encoding="utf-8") != content:
                    raise ValueError(f"Stale or missing catalog: {path}")
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8")
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print("Problem catalog: OK" + (" (checked)" if args.check else " (generated)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
