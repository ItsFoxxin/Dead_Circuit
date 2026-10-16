"""Install checksum-pinned Godot, GUT and development export templates locally."""

import argparse
import hashlib
import json
import platform
import shutil
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT / "tools/toolchain.json").read_text())
TOOLS = ROOT / ".tools"


def sha256(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def download(url: str, name: str, digest: str) -> Path:
    target = TOOLS / "downloads" / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists() or sha256(target) != digest:
        print(f"Downloading {name}", flush=True)
        request = urllib.request.Request(url, headers={"User-Agent": "Dead-Circuit-bootstrap"})
        with urllib.request.urlopen(request, timeout=120) as response, target.open("wb") as output:
            shutil.copyfileobj(response, output)
    actual = sha256(target)
    if actual != digest:
        raise RuntimeError(f"Checksum mismatch for {name}: {actual}")
    return target


def extract(archive: Path, destination: Path, prefix: str = "") -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            if member.is_dir() or not member.filename.startswith(prefix):
                continue
            relative = member.filename[len(prefix):]
            target = (destination / relative).resolve()
            if not target.is_relative_to(destination.resolve()):
                raise RuntimeError(f"Unsafe archive path: {member.filename}")
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open(member) as content, target.open("wb") as output:
                shutil.copyfileobj(content, output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--templates", action="store_true")
    args = parser.parse_args()
    system = platform.system()
    if platform.machine().lower() not in ("amd64", "x86_64") or system not in LOCK["godot"]:
        parser.error("Bootstrap supports Windows/Linux x86_64 hosts.")
    base = f"https://github.com/godotengine/godot-builds/releases/download/{LOCK['godot_release']}"
    engine = LOCK["godot"][system]
    extract(download(f"{base}/{engine['asset']}", engine["asset"], engine["sha256"]), TOOLS / "godot")
    for executable in (TOOLS / "godot").iterdir():
        executable.chmod(0o755)
    gut = LOCK["gut"]
    archive = download(f"https://codeload.github.com/bitwes/Gut/zip/{gut['commit']}", "gut.zip", gut["sha256"])
    extract(archive, ROOT / "addons/gut", f"Gut-{gut['commit']}/addons/gut/")
    if args.templates:
        templates = LOCK["templates"]
        archive = download(f"{base}/{templates['asset']}", templates["asset"], templates["sha256"])
        with zipfile.ZipFile(archive) as source:
            for name in ("windows_debug_x86_64.exe", "linux_debug.x86_64"):
                target = TOOLS / "export_templates" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(source.read("templates/" + name))
                target.chmod(0o755)
    print("Pinned toolchain installed. Run python tools/dev.py validate.")


if __name__ == "__main__":
    main()
