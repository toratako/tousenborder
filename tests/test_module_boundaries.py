"""Keep runtime dependencies directed toward rules, not screens or composition."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src"


def dependencies():
    sources = {path: path.read_text() for path in SOURCE.rglob("*.gd")}
    classes = {}
    for path, source in sources.items():
        match = re.search(r"^class_name (\w+)", source, re.MULTILINE)
        if match:
            classes[match[1]] = path
    graph = {}
    for path, source in sources.items():
        # Mask comments and strings before finding references to global classes.
        code = re.sub(r'"(?:\\.|[^"\\])*"|#[^\n]*', "", source)
        identifiers = set(re.findall(r"\b\w+\b", code))
        references = {classes[name] for name in identifiers & classes.keys()}
        for resource in re.findall(
            r'\b(?:preload|load)\("res://(src/[^"\n]+\.gd)"\)', source
        ):
            references.add(ROOT / resource)
        graph[path] = references - {path}
    return graph


class ModuleBoundaryTests(unittest.TestCase):
    def test_layers_do_not_depend_on_their_callers(self):
        allowed = {
            "domain": {"domain"},
            "validation": {"validation"},
            "content": {"content", "domain", "validation"},
            "persistence": {"persistence", "content", "domain", "validation"},
            "ui": {"ui", "content", "domain", "persistence", "validation"},
            "app": {"app", "ui", "content", "domain", "persistence", "validation"},
        }
        for source, targets in dependencies().items():
            layer = source.relative_to(SOURCE).parts[0]
            for target in targets:
                with self.subTest(
                    source=source.relative_to(ROOT), target=target.relative_to(ROOT)
                ):
                    self.assertIn(target.relative_to(SOURCE).parts[0], allowed[layer])

    def test_runtime_modules_have_no_dependency_cycles(self):
        graph = dependencies()
        visited = set()

        def visit(path, route):
            self.assertNotIn(
                path,
                route,
                " -> ".join(str(p.relative_to(SOURCE)) for p in [*route, path]),
            )
            if path in visited:
                return
            for target in graph[path]:
                visit(target, [*route, path])
            visited.add(path)

        for path in graph:
            visit(path, [])
