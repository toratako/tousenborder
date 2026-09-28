#!/usr/bin/env python3
"""公式GodotテンプレートをLinux・Windows x86_64向けに導入する。"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile


REQUIRED = (
    "linux_debug.x86_64",
    "linux_release.x86_64",
    "windows_debug_x86_64.exe",
    "windows_release_x86_64.exe",
)


def detect_version(godot):
    result = subprocess.run(
        [godot, "--version"], check=True, capture_output=True, text=True
    )
    match = re.match(
        r"^(\d+\.\d+(?:\.\d+)?)\.(stable|rc\d+|beta\d+|dev\d+)(?:\.|$)",
        result.stdout.strip(),
    )
    if not match:
        raise ValueError("公式リリースに対応するGodotのバージョンを判別できません。")
    number, channel = match.groups()
    return f"{number}.{channel}", f"{number}-{channel}"


def template_root():
    # justfileはPOSIX環境向け。GodotのLinux標準配置とXDG設定に合わせる。
    configured = os.environ.get("XDG_DATA_HOME")
    data = Path(configured) if configured else Path.home() / ".local/share"
    if not data.is_absolute():
        raise ValueError("XDG_DATA_HOMEは絶対パスで指定してください。")
    return data / "godot/export_templates"


def is_installed(destination, version):
    return (
        destination.is_dir()
        and not destination.is_symlink()
        and all(
            (destination / name).is_file() and (destination / name).stat().st_size > 0
            for name in REQUIRED
        )
        and (destination / "version.txt").is_file()
        and (destination / "version.txt").read_text().strip() == version
    )


def request(url):
    return urllib.request.urlopen(
        urllib.request.Request(
            url, headers={"User-Agent": "tousenborder-template-installer"}
        ),
        timeout=60,
    )


def release_asset(tag):
    with request(
        f"https://api.github.com/repos/godotengine/godot-builds/releases/tags/{tag}"
    ) as response:
        release = json.load(response)
    name = f"Godot_v{tag}_export_templates.tpz"
    asset = next((a for a in release["assets"] if a["name"] == name), None)
    if asset is None:
        raise ValueError(f"公式テンプレートが見つかりません: {name}")
    digest = asset.get("digest") or ""
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise ValueError("公式SHA-256が取得できないため、インストールを中止しました。")
    expected_url = (
        f"https://github.com/godotengine/godot-builds/releases/download/{tag}/{name}"
    )
    if asset["browser_download_url"] != expected_url:
        raise ValueError("公式リリースのダウンロードURLが想定と異なります。")
    return asset


def download(asset, archive):
    print(
        f"公式テンプレートを取得: {asset['name']}（約{asset['size'] / 1_000_000:.0f} MB）",
        flush=True,
    )
    total = 0
    reported = 0
    with (
        request(asset["browser_download_url"]) as response,
        archive.open("wb") as output,
    ):
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
            total += len(chunk)
            if total - reported >= 64 * 1024 * 1024:
                print(f"取得済み: {total / 1_000_000:.0f} MB", flush=True)
                reported = total


def install_archive(archive, destination, version, digest):
    with archive.open("rb") as source:
        actual = hashlib.file_digest(source, "sha256").hexdigest()
    if actual != digest.removeprefix("sha256:"):
        raise ValueError(
            "テンプレートのSHA-256が一致しません。配置は変更していません。"
        )
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        selected = [
            name
            for name in names
            if name.startswith("templates/")
            and (
                name.removeprefix("templates/") in (*REQUIRED, "version.txt")
                or re.fullmatch(
                    r"templates/windows_(debug|release)_x86_64_console\.exe",
                    name,
                )
                or re.fullmatch(r"templates/icudt[^/]*\.dat", name)
            )
        ]
        if any(
            names.count("templates/" + name) != 1 for name in (*REQUIRED, "version.txt")
        ):
            raise ValueError(
                "アーカイブに必要なテンプレートが揃っていないか、重複しています。"
            )
        if bundle.read("templates/version.txt").decode().strip() != version:
            raise ValueError("アーカイブ内のバージョンがGodotと一致しません。")
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(
            prefix=".install-", dir=destination.parent
        ) as temporary:
            staging = Path(temporary) / version
            staging.mkdir()
            for name in selected:
                target = staging / Path(name).name
                with bundle.open(name) as source, target.open("xb") as output:
                    shutil.copyfileobj(source, output)
                target.chmod(0o755 if target.name.startswith("linux_") else 0o644)
            if not is_installed(staging, version):
                raise ValueError("展開したテンプレートを検証できませんでした。")
            if os.path.lexists(destination):
                raise ValueError(
                    f"導入先が既に存在するため上書きしません: {destination}"
                )
            staging.rename(destination)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT", "godot"),
        help="Godotの実行ファイル",
    )
    args = parser.parse_args()
    version, tag = detect_version(args.godot)
    destination = template_root() / version
    if is_installed(destination, version):
        print(f"導入済み: {destination}")
        return
    if os.path.lexists(destination):
        raise ValueError(
            f"導入先が既に存在します。既存ファイルは上書きしません: {destination}"
        )
    asset = release_asset(tag)
    with tempfile.TemporaryDirectory(prefix="godot-template-download-") as temporary:
        supplied = os.environ.get("GODOT_TEMPLATE_ARCHIVE")
        archive = Path(supplied) if supplied else Path(temporary) / asset["name"]
        if not supplied:
            download(asset, archive)
        print("SHA-256を検証し、テンプレートを配置します。", flush=True)
        install_archive(archive, destination, version, asset["digest"])
    print(f"導入完了: {destination}\n次に just build を実行できます。")


if __name__ == "__main__":
    try:
        main()
    except (
        OSError,
        ValueError,
        KeyError,
        zipfile.BadZipFile,
        subprocess.CalledProcessError,
    ) as error:
        print(f"テンプレート導入失敗: {error}", file=sys.stderr)
        sys.exit(1)
