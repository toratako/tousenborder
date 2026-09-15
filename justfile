godot := env("GODOT", "godot")

default:
    @just --list

build: clean build-linux build-windows

install-templates:
    python3 scripts/install_templates.py --godot "{{ godot }}"

clean:
    rm -rf -- build

build-linux: _import
    mkdir -p build/linux
    "{{ godot }}" --headless --path . --export-release "Linux" build/linux/packets-please.x86_64

build-windows: _import
    mkdir -p build/windows
    "{{ godot }}" --headless --path . --export-release "Windows" build/windows/packets-please.exe

[private]
_import:
    "{{ godot }}" --headless --path . --editor --import --quit
