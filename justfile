godot := env("GODOT", "godot")
python := env("PYTHON", "python3")

default:
    @just --list

run: _validate
    "{{ godot }}" --path .

validate: _validate
    "{{ python }}" scripts/build_problem_catalog.py --check

test: _import
    GODOT="{{ godot }}" "{{ python }}" scripts/run_tests.py

format:
    if command -v gdscript-formatter >/dev/null 2>&1; then gdscript-formatter src scripts tests; fi
    ruff format scripts tests

build: clean build-linux build-windows

install-templates:
    "{{ python }}" scripts/install_templates.py --godot "{{ godot }}"

clean:
    rm -rf -- build

build-linux: _validate
    mkdir -p build/linux
    "{{ godot }}" --headless --path . --export-release "Linux" build/linux/tousenborder.x86_64

build-windows: _validate
    mkdir -p build/windows
    "{{ godot }}" --headless --path . --export-release "Windows" build/windows/tousenborder.exe

[private]
_validate: _import
    "{{ godot }}" --headless --path . --script scripts/validate_content.gd

[private]
_import:
    "{{ godot }}" --headless --path . --editor --import --quit
