"""Generate a review index from the game's content loader (contains answers)."""

from __future__ import annotations

import argparse
from collections import Counter
import html
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def load_report(source: Path, godot: str | None = None) -> dict:
    command = [
        godot or os.environ.get("GODOT", "godot"),
        "--headless",
        "--path",
        str(ROOT),
        "--script",
        "scripts/validate_content.gd",
        "--",
        "--report",
        str(source.resolve()),
    ]
    result = subprocess.run(command, capture_output=True, text=True, timeout=60)
    if result.returncode or "ERROR:" in result.stderr:
        raise ValueError(
            result.stderr.strip()
            or result.stdout.strip()
            or "Content validation failed"
        )
    reports = [
        line.removeprefix("CONTENT_REPORT:")
        for line in result.stdout.splitlines()
        if line.startswith("CONTENT_REPORT:")
    ]
    if len(reports) != 1:
        raise ValueError(
            "The content loader did not return a report; run Godot editor import first"
        )
    return json.loads(reports[0])


def cell(value: object) -> str:
    text = html.escape(str(value), quote=False)
    for literal in "\\|*_`[]":
        text = text.replace(literal, f"&#{ord(literal)};")
    return text.replace("\r", "").replace("\n", "<br>")


def build(source: Path = ROOT / "data", godot: str | None = None) -> tuple[str, str]:
    report = load_report(source, godot)
    problems = sorted(
        report["problems"], key=lambda item: (item["source_id"], item["id"])
    )
    fields = (
        "id",
        "source_id",
        "source_path",
        "definition_hash",
        "category",
        "platform",
        "difficulty",
        "traits",
        "title",
        "ground_truth",
        "explanation",
    )
    rows = [{key: item[key] for key in fields} for item in problems]
    result = {
        "schema_version": 2,
        "total": len(rows),
        "by_category": dict(sorted(Counter(p["category"] for p in rows).items())),
        "by_difficulty": dict(sorted(Counter(p["difficulty"] for p in rows).items())),
        "by_method": dict(sorted(Counter(p["traits"]["method"] for p in rows).items())),
        "packs": report["packs"],
        "problems": rows,
    }
    lines = [
        "# 問題一覧",
        "",
        f"公開教材 {len(rows)}問．問題JSONから生成した開発者用の索引．",
        "`python3 scripts/build_problem_catalog.py` で再生成．`--check` で差分を検証．",
        "",
        "| ID | 分野 | OS | 難易度 | 調査形式 | Title | 正解 |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for item in rows:
        label = cell(item["id"])
        if source.is_dir():
            link = os.path.relpath(source / item["source_path"], ROOT / "docs").replace(
                os.sep, "/"
            )
            label = f"[{label}](<{link}>)"
        values = [
            item["category"],
            item["platform"],
            item["difficulty"],
            item["traits"]["method"],
            item["title"],
            item["ground_truth"].upper(),
        ]
        lines.append("| " + label + " | " + " | ".join(cell(v) for v in values) + " |")
    return json.dumps(result, ensure_ascii=False, indent=2) + "\n", "\n".join(
        lines
    ) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check Markdown and existing JSON without writing",
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=ROOT / "data",
        help="Content directory, standalone JSON, or ZIP (default: data)",
    )
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT", "godot"),
        help="Godot executable (default: $GODOT or godot)",
    )
    parser.add_argument(
        "--json-output", type=Path, default=ROOT / "build/catalog/problems.json"
    )
    parser.add_argument(
        "--markdown-output", type=Path, default=ROOT / "docs/problem-catalog.md"
    )
    args = parser.parse_args()
    try:
        outputs = build(args.source.resolve(), args.godot)
        targets = [args.json_output, args.markdown_output]
        if args.check:
            for index, (path, content) in enumerate(zip(targets, outputs)):
                if index == 0 and not path.exists():
                    continue
                if not path.exists() or path.read_text(encoding="utf-8") != content:
                    raise ValueError(f"Stale or missing index: {path}")
        else:
            for path, content in zip(targets, outputs):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="\n")
    except (ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print("Problem index: OK" + (" (checked)" if args.check else " (generated)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
