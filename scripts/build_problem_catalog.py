"""Validate the canonical content schemas and semantics, then generate the catalog."""
from __future__ import annotations

import argparse
from collections import Counter
from functools import lru_cache
import html
import json
import math
from pathlib import Path
import sys

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[1]
LEVEL_LABELS = {
    "very_beginner": "超初級", "beginner_reference": "初級：Referenceのみ", "beginner": "初級：Tool",
    "beginner_external": "初級：External Referenceあり", "intermediate": "中級", "advanced": "上級",
}
GROUP_KINDS = {"tools": "tools", "references": "references", "external_references": "external_references"}

@lru_cache(maxsize=4)
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
    os = "linux" if item["platform"] == "common" else item["platform"]
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
            if entry.get("correct_usage", True):
                available.add(entry["id"])
                obtained.update((entry["id"], o["id"]) for o in entry.get("output_information", []) if o.get("tool_input", True))
            pending.remove((kind, entry))
    for key in item["required_evidence"]:
        options = item.get("evidence_alternatives", {}).get(key, {}).get("any_of", [key])
        if not available.intersection(options):
            raise ValueError(f"{item['id']}: required evidence unavailable on {os} through permitted investigations: {key}")


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
    if item["level"] == "very_beginner" and any(kind != "references" for kind, _ in entries):
        raise ValueError(f"{item['id']}: very_beginner investigations allow only Reference resources")
    has_external = any(kind == "external_references" for kind, _ in entries)
    has_tool = any(kind == "tools" for kind, _ in entries)
    if item["level"] == "beginner" and has_external:
        raise ValueError(f"{item['id']}: beginner with External Reference must use beginner_external")
    if item["level"] == "beginner" and not has_tool:
        raise ValueError(f"{item['id']}: beginner without Tool must use beginner_reference")
    if item["level"] == "beginner_reference" and (not entries or has_tool or has_external):
        raise ValueError(f"{item['id']}: beginner_reference requires Reference resources only")
    if item["level"] == "beginner_external" and not has_external:
        raise ValueError(f"{item['id']}: beginner_external requires External Reference")
    validate_glossary(item, pack, entries)
    validate_inputs(item, entries)
    return entries


def validate_review(item: dict, entries: list[tuple[str, dict]], review: dict) -> None:
    """The authored walkthrough must be executable, safe and evidence-complete."""
    resources = {entry["id"]: entry for _, entry in entries}
    if item["level"] == "beginner":
        tool_ids = {entry["id"] for kind, entry in entries if kind == "tools"}
        used_tools = {step["resource_id"] for step in review["flow"]} & tool_ids
        if len(used_tools) != 1:
            raise ValueError(f"{item['id']}: beginner walkthrough must use exactly one Tool")
    os = "linux" if item["platform"] == "common" else item["platform"]
    obtained = {("initial_information", key) for key in item["initial_information"]}
    visited = {"initial_information"}
    for step in review["flow"]:
        key = step["resource_id"]
        if key == "initial_information":
            continue
        if key not in resources:
            raise ValueError(f"{item['id']}: review flow refers to missing resource {key}")
        entry = resources[key]
        if not entry.get("correct_usage", True) or (entry.get("environments") and os not in entry["environments"]):
            raise ValueError(f"{item['id']}: review flow uses an unsafe or unavailable resource {key}")
        if entry.get("input_bindings") and not any(
            (binding["source"], binding["id"]) in obtained for binding in entry["input_bindings"]
        ):
            raise ValueError(f"{item['id']}: review flow uses {key} before its input is available")
        visited.add(key)
        obtained.update((key, output["id"]) for output in entry.get("output_information", [])
                        if output.get("tool_input", True))
    for key in item["required_evidence"]:
        options = item.get("evidence_alternatives", {}).get(key, {}).get("any_of", [key])
        if not visited.intersection(options):
            raise ValueError(f"{item['id']}: review flow omits required evidence {key}")


def display_value(value) -> str:
    """Readable initial facts; only explicit code strings retain JSON punctuation."""
    if isinstance(value, dict):
        return " / ".join(f"{key}: {display_value(part)}" for key, part in value.items()) or "なし"
    if isinstance(value, list):
        return "、".join(display_value(part) for part in value) or "なし"
    return str(value)


def validate_glossary(item: dict, pack: dict, entries: list[tuple[str, dict]]) -> None:
    terms = {}
    if 'glossary_path' in pack:
        glossary = read_json(resource_path(pack['glossary_path']))
        validate_schema(glossary, 'glossary')
        terms = glossary['terms']
        if any(not key.strip() for key in terms):
            raise ValueError('Empty glossary term ID')
    sources = {entry['id']: kind for kind, entry in entries}
    seen = set()
    for entry in item.get('glossary', []):
        term_id = entry['term_id']
        if term_id not in terms or term_id in seen:
            raise ValueError(f'Unknown or duplicate glossary term: {term_id}')
        seen.add(term_id)
        for occurrence in entry['occurrences']:
            source, section = occurrence['source_id'], occurrence['section']
            if section == 'initial':
                if source != 'initial_information':
                    raise ValueError('Initial glossary source must be initial_information')
            elif source not in sources:
                raise ValueError(f'Unknown glossary source: {source}')
            elif section == 'submission' and sources[source] != 'external_references':
                raise ValueError('Submission glossary source must be external')


def build(pack_path: Path) -> tuple[str, str]:
    pack = read_json(pack_path)
    pack_resource = "res://" + pack_path.relative_to(ROOT).as_posix()
    review_path = pack_path.parent.parent / "catalog" / pack_path.name
    reviews = None
    if review_path.exists():
        review_data = read_json(review_path)
        validate_schema(review_data, "catalog-review")
        if review_data["content_pack"] != pack_resource:
            raise ValueError(f"Catalog review content_pack mismatch: {review_path}")
        reviews = review_data["reviews"]
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
            "id", "category", "platform", "level", "ground_truth", "title", "topic", "summary",
            "scenario_type", "decision_context", "learning_objectives", "required_evidence", "sources",
        ]}
        problem.update(path=value, ecosystem=item.get("ecosystem", ""), inspired_by=item.get("inspired_by", ""))
        problem["evidence_alternatives"] = item.get("evidence_alternatives", {})
        names = {entry["id"]: entry["name"] for _, entry in entries}
        names["initial_information"] = "初期情報"
        problem["main_evidence"] = [
            {"id": key, "label": problem["evidence_alternatives"].get(key, {}).get("label", names.get(key, key)),
             "any_of": problem["evidence_alternatives"].get(key, {}).get("any_of", [key])}
            for key in item["required_evidence"]
        ]
        # 必須証拠とその入力元を辿る。代替経路を含め、到達不能なOSの候補は載せない。
        needed = {option for evidence in problem["main_evidence"] for option in evidence["any_of"]}
        os = "linux" if item["platform"] == "common" else item["platform"]
        usable = [entry for _, entry in entries if entry.get("correct_usage", True)
                  and (not entry.get("environments") or os in entry["environments"])]
        while True:
            expanded = needed | {binding["source"] for entry in usable if entry["id"] in needed
                                 for binding in entry.get("input_bindings", [])}
            if expanded == needed:
                break
            needed = expanded
        problem["main_tools"] = [entry["name"] for kind, entry in entries
                                 if kind == "tools" and entry in usable and entry["id"] in needed]
        for kind in GROUP_KINDS:
            problem[kind] = [entry["name"] for entry_kind, entry in entries if entry_kind == kind]
        problem["investigation_inputs"] = [
            {"resource_id": entry["id"], "name": entry["name"], "input_hint": entry.get("input_hint", ""),
             "accepted_information_types": entry.get("accepted_information_types", []),
             "environments": entry.get("environments", []),
             "input_bindings": entry.get("input_bindings", [])}
            for kind, entry in entries if kind != "references"
        ]
        review = reviews.get(item["id"]) if reviews is not None else None
        if reviews is not None and review is None:
            raise ValueError(f"Missing catalog review: {item['id']}")
        if review is not None:
            validate_review(item, entries, review)
        problem.update(
            overview=review["overview"] if review else item["summary"],
            request=item["request"],
            initial_information=item["initial_information"],
            expected_investigation_flow=[
                {"resource_id": step["resource_id"], "name": names[step["resource_id"]], "action": step["action"]}
                for step in review["flow"]
            ] if review else [],
            decisive_evidence=review["decisive_evidence"] if review else "未レビュー",
            reason=item["explanation"],
            review_notes=review.get("review_notes", "") if review else "レビュー用JSONが未作成。想定手順と決定的な証拠は未レビュー。",
            available_investigation=[
                {"resource_id": entry["id"], "kind": kind, "name": entry["name"],
                 "available": not entry.get("environments") or os in entry["environments"],
                 "correct_usage": entry.get("correct_usage", True),
                 "reason": entry.get("reason", "")}
                for kind, entry in entries
            ],
        )
        problems.append(problem)
    if reviews is not None and set(reviews) != seen:
        raise ValueError("Catalog reviews refer to unregistered problems: " + ", ".join(sorted(set(reviews) - seen)))
    total = len(problems)
    if total == 0:
        raise ValueError("The content pack contains no problems")
    inspired = sum(p["scenario_type"] == "real_world_inspired" for p in problems)
    result = {
        "schema_version": 1, "content_pack": pack_resource,
        "total": total, "by_category": dict(Counter(p["category"] for p in problems)),
        "by_level": dict(Counter(p["level"] for p in problems)),
        "by_platform": dict(Counter(p["platform"] for p in problems)),
        "by_verdict": dict(Counter(p["ground_truth"] for p in problems)),
        "real_world_inspired": inspired,
        "review_source": "res://" + review_path.relative_to(ROOT).as_posix() if reviews is not None else None,
        "problems": problems,
    }
    lines = [
        "# Problem Catalog / 人間向け全問題確認表", "",
        f"対象: {result['content_pack']}。実装済み{total}問。"
        f"許可{result['by_verdict'].get('allow', 0)}問・遮断{result['by_verdict'].get('block', 0)}問。"
        f"Real-world inspired {inspired}問（{inspired / total:.1%}）。",
        "", "開発者・レビュー担当者向け。Titleは回答後の表示名で、この一覧には正解を含みます。"
        "問題JSONとレビュー用JSONを編集し、python scripts/build_problem_catalog.py で再生成してください。"
        "検証のみの場合は --check を指定します。",
        "", "Initial Informationはプレイヤーに提示される事実のみ。Available Investigationは補助資料も含む全候補です。"
        "Expected Investigation Flowは必要証拠を満たす代表経路で、最後にCorrect Answerの判定を行います。"
        "代替手段の全候補はMain Evidenceに記載します。資料の生OutputはIDリンク先の問題JSONを参照してください。",
        "", "| ID | Category | Platform / Ecosystem | Difficulty | Title | Scenario Type | Overview | Initial Information | Available Investigation | Expected Investigation Flow | Decisive Evidence | Correct Answer | Reason | Learning Objective | Real-world Inspiration |",
        "| " + " | ".join(["---"] * 15) + " |",
    ]
    def cell(value):
        # Escape literal HTML/Markdown (including Windows paths and placeholder code).
        text = html.escape(str(value), quote=False)
        for literal in "\\|*_`[]":
            text = text.replace(literal, f"&#{ord(literal)};")
        return text.replace("\r", "").replace("\n", "<br>")
    for p in problems:
        link = "../" + p["path"][6:]
        available = []
        for kind, label in [("tools", "Tool"), ("references", "Reference"), ("external_references", "External Reference")]:
            resources = []
            for entry in p["available_investigation"]:
                if entry["kind"] == kind:
                    note = "（この調査OSでは利用不可）" if not entry["available"] else ""
                    if not entry["correct_usage"]:
                        note += "（利用不適切：" + entry["reason"] + "）"
                    resources.append(entry["name"] + note)
            available.append(label + ": " + ("、".join(resources) or "なし"))
        flow = [f"{i}. {step['name']}：{step['action']}"
                for i, step in enumerate(p["expected_investigation_flow"], 1)]
        if flow:
            flow.append(f"{len(flow) + 1}. 照合結果から{p['ground_truth'].upper()}と判断する")
        values = [
            p["category"].title(), p["platform"].title() + (f" / {p['ecosystem']}" if p["ecosystem"] else ""),
            LEVEL_LABELS.get(p["level"], p["level"]), p["title"],
            {"standard": "Normal", "real_world_inspired": "Real-world inspired"}.get(p["scenario_type"], p["scenario_type"]),
            p["overview"], "\n".join(f"{key}: {display_value(value)}" for key, value in p["initial_information"].items()),
            "\n".join(available), "\n".join(flow) or "未レビュー", p["decisive_evidence"],
            p["ground_truth"].upper(), p["reason"], "\n".join(p["learning_objectives"]), p["inspired_by"] or "—",
        ]
        lines.append(f"| [{p['id']}]({link}) | " + " | ".join(cell(v) for v in values) + " |")
    notes = [p for p in problems if p["review_notes"]]
    if notes:
        lines += ["", "## 設計レビュー注記", "", "元の問題に残る説明不足です。Catalogだけで不足を補って問題が成立したとは扱いません。", "", "| ID | 確認事項 |", "| --- | --- |"]
        for p in notes:
            lines.append(f"| {p['id']} | {cell(p['review_notes'])} |")
    lines += ["", "## Main Evidence / 必須資料と代替手段", "", "代表経路で省略した代替候補を含みます。資料名は証拠の所在であり、判断を成立させる事実は上表のDecisive Evidenceに記載しています。", "", "| ID | Main Evidence | Main Tool |", "| --- | --- | --- |"]
    for p in problems:
        names = {entry["resource_id"]: entry["name"] for entry in p["available_investigation"]}
        names["initial_information"] = "初期情報"
        labels = [e["label"] + ("（" + " / ".join(names[key] for key in e["any_of"]) + "）" if e["id"] in p["evidence_alternatives"] else "")
                  for e in p["main_evidence"]]
        lines.append(f"| {p['id']} | {cell('、'.join(labels))} | {cell('、'.join(p['main_tools']) or '—')} |")
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
                path.write_text(content, encoding="utf-8", newline="\n")
    except (ValueError, KeyError, TypeError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print("Problem catalog: OK" + (" (checked)" if args.check else " (generated)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
