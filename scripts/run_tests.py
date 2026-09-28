"""Run checks after Godot import; fail on script errors even if Godot exits zero."""

from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    godot = os.environ.get("GODOT", "godot")
    commands = [
        [
            sys.executable,
            "-m",
            "unittest",
            "discover",
            "-s",
            "tests",
            "-p",
            "test_*.py",
        ],
        [sys.executable, "scripts/build_problem_catalog.py", "--check"],
        [godot, "--headless", "--path", ".", "--script", "scripts/validate_content.gd"],
    ]
    commands.extend(
        [godot, "--headless", "--path", ".", "--script", str(path.relative_to(ROOT))]
        for path in sorted((ROOT / "tests").glob("test_*.gd"))
    )
    for command in commands:
        print("Running:", " ".join(command), flush=True)
        try:
            result = subprocess.run(
                command, cwd=ROOT, capture_output=True, text=True, timeout=60
            )
        except subprocess.TimeoutExpired as error:
            print(error.stdout or "", error.stderr or "", file=sys.stderr)
            print("Test timed out", file=sys.stderr)
            return 1
        except OSError as error:
            print(error, file=sys.stderr)
            return 1
        print(result.stdout, end="")
        print(result.stderr, end="", file=sys.stderr)
        if (
            result.returncode
            or "SCRIPT ERROR:" in result.stderr
            or "ERROR:" in result.stderr
        ):
            return 1
    print("All checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
