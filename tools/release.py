"""Fail-closed version approval and release packaging; never creates tags/releases."""

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TAG = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")
PLATFORMS = {"windows": "DeadCircuit.exe", "linux": "DeadCircuit.x86_64"}


def tag_version(tag: str) -> tuple[str, bool]:
    match = TAG.fullmatch(tag)
    if match is None:
        raise RuntimeError("Expected vMAJOR.MINOR.PATCH without leading zeros or suffixes")
    return tag[1:], match[1] == "0"


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def validate(tag: str, *, dry_run: bool = False) -> dict:
    version, prerelease = tag_version(tag)
    if (ROOT / "VERSION").read_text().strip() != version:
        raise RuntimeError("Tag version does not match VERSION")
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    sections = re.findall(r"(?ms)^\[application\]\s*\n(.*?)(?=^\[|\Z)", project)
    versions = re.findall(r'^config/version="([^"]+)"\s*$', sections[0], re.MULTILINE) if len(sections) == 1 else []
    if versions != [version]:
        raise RuntimeError("Tag version does not match project.godot application/config/version")
    sha = git("rev-parse", "HEAD")
    if not dry_run:
        if git("rev-parse", f"refs/tags/{tag}^{{commit}}") != sha:
            raise RuntimeError("Checkout is not the tagged commit")
        git("rev-parse", "--verify", "origin/main")
        result = subprocess.run(["git", "merge-base", "--is-ancestor", sha, "origin/main"], cwd=ROOT)
        if result.returncode != 0:
            raise RuntimeError("Tagged commit is not reachable from origin/main")
    plan = {"tag": tag, "version": version, "prerelease": prerelease,
            "commit_sha": sha, "dry_run": dry_run}
    return plan


def digest(path: Path) -> str:
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def verify_checksums(text: str, expected: set[str], hashes: dict[str, str]) -> None:
    actual = {}
    for line in text.splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if match is None or match[2] in actual:
            raise RuntimeError("Malformed or duplicate checksum entry")
        actual[match[2]] = match[1]
    if set(actual) != expected or actual != hashes:
        raise RuntimeError("Missing file or checksum mismatch")


def verify_metadata(data: dict, tag: str, platform: str, sha: str) -> None:
    version, _ = tag_version(tag)
    lock = json.loads((ROOT / "tools/toolchain.json").read_text())
    required = {"version": version, "tag": tag, "commit_sha": sha,
                "build_type": "release", "platform": platform,
                "dirty": False, "native_smoke_passed": True}
    if any(data.get(key) != value for key, value in required.items()):
        raise RuntimeError("Release provenance or native smoke result does not match")
    if data.get("dirty") is not False or data.get("native_smoke_passed") is not True:
        raise RuntimeError("Release requires clean provenance and a native smoke pass")
    if not str(data.get("engine_version", "")).startswith(lock["godot_version"] + ".stable."):
        raise RuntimeError("Release engine does not match the pinned stable engine")
    if not data.get("build_id") or not data.get("ci_run_id"):
        raise RuntimeError("Release provenance requires build and run IDs")


def archive_name(tag: str, platform: str) -> str:
    tag_version(tag)
    if platform not in PLATFORMS:
        raise RuntimeError("Unsupported release platform")
    return f"DeadCircuit-{tag}-{platform}-x86_64.zip"


def package(tag: str, platform: str, source: Path, destination: Path, sha: str) -> Path:
    binary = PLATFORMS[platform]
    names = {binary, "build-metadata.json", "SHA256SUMS.txt"}
    if not source.is_dir() or {path.name for path in source.iterdir()} != names:
        raise RuntimeError("Missing or unexpected release export files")
    if any(not (source / name).is_file() or (source / name).is_symlink() for name in names):
        raise RuntimeError("Release files must be regular files")
    if (source / binary).stat().st_size == 0:
        raise RuntimeError("Empty release binary")
    data = json.loads((source / "build-metadata.json").read_text())
    verify_metadata(data, tag, platform, sha)
    checked = names - {"SHA256SUMS.txt"}
    verify_checksums((source / "SHA256SUMS.txt").read_text(), checked,
                     {name: digest(source / name) for name in checked})
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / archive_name(tag, platform)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in sorted(names):
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if name == binary and platform == "linux" else 0o644
            info.external_attr = (stat.S_IFREG | mode) << 16
            with (source / name).open("rb") as content, archive.open(info, "w") as target:
                shutil.copyfileobj(content, target)
    verify_package(output, tag, platform, sha)
    return output


def verify_package(path: Path, tag: str, platform: str, sha: str) -> dict:
    binary = PLATFORMS[platform]
    expected = {binary, "build-metadata.json", "SHA256SUMS.txt"}
    with zipfile.ZipFile(path) as archive:
        if set(archive.namelist()) != expected or len(archive.namelist()) != len(expected):
            raise RuntimeError("Missing, duplicate or unexpected ZIP members")
        for info in archive.infolist():
            if not stat.S_ISREG(info.external_attr >> 16):
                raise RuntimeError("ZIP members must be regular files")
        if archive.getinfo(binary).file_size == 0:
            raise RuntimeError("Empty packaged binary")
        if platform == "linux" and not archive.getinfo(binary).external_attr >> 16 & 0o111:
            raise RuntimeError("Linux ZIP must preserve executable permissions")
        data = json.loads(archive.read("build-metadata.json"))
        verify_metadata(data, tag, platform, sha)
        hashes = {}
        for name in expected - {"SHA256SUMS.txt"}:
            with archive.open(name) as content:
                hashes[name] = hashlib.file_digest(content, "sha256").hexdigest()
        verify_checksums(archive.read("SHA256SUMS.txt").decode(), set(hashes), hashes)
        return data


def assemble(tag: str, source: Path, destination: Path, sha: str) -> None:
    version, prerelease = tag_version(tag)
    expected = {archive_name(tag, platform) for platform in PLATFORMS}
    if {path.name for path in source.iterdir()} != expected:
        raise RuntimeError("Both fresh native release packages are required")
    platforms = {name: verify_package(source / archive_name(tag, name), tag, name, sha)
                 for name in PLATFORMS}
    common = ("engine_version", "build_id", "ci_run_id")
    if any(platforms["windows"][key] != platforms["linux"][key] for key in common):
        raise RuntimeError("Native packages have different build provenance")
    if os.environ.get("GITHUB_RUN_ID") and platforms["windows"]["ci_run_id"] != os.environ["GITHUB_RUN_ID"]:
        raise RuntimeError("Packages must come from this workflow run")
    destination.mkdir(parents=True, exist_ok=True)
    for name in sorted(expected):
        shutil.copyfile(source / name, destination / name)
    data = {"version": version, "tag": tag, "commit_sha": sha,
            "engine_version": platforms["windows"]["engine_version"], "build_type": "release",
            "prerelease": prerelease, "platforms": platforms}
    (destination / "build-metadata.json").write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    checked = expected | {"build-metadata.json"}
    (destination / "SHA256SUMS.txt").write_text(
        "".join(f"{digest(destination / name)}  {name}\n" for name in sorted(checked)), encoding="utf-8")
    verify_assets(tag, destination, sha)


def verify_assets(tag: str, directory: Path, sha: str) -> dict:
    checked = {archive_name(tag, name) for name in PLATFORMS} | {"build-metadata.json"}
    if {path.name for path in directory.iterdir()} != checked | {"SHA256SUMS.txt"}:
        raise RuntimeError("Release requires exactly two ZIPs, metadata and checksums")
    verify_checksums((directory / "SHA256SUMS.txt").read_text(), checked,
                     {name: digest(directory / name) for name in checked})
    data = json.loads((directory / "build-metadata.json").read_text())
    version, prerelease = tag_version(tag)
    if any(data.get(key) != value for key, value in {
        "tag": tag, "version": version, "commit_sha": sha, "prerelease": prerelease,
        "build_type": "release"}.items()):
        raise RuntimeError("Combined release metadata does not match")
    for name in PLATFORMS:
        actual = verify_package(directory / archive_name(tag, name), tag, name, sha)
        if actual != data.get("platforms", {}).get(name) or actual["engine_version"] != data.get("engine_version"):
            raise RuntimeError("Combined release provenance differs from ZIP provenance")
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "package", "assemble", "verify"))
    parser.add_argument("--tag", default="")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--platform", choices=tuple(PLATFORMS), default="windows")
    parser.add_argument("--input", type=Path, default=ROOT / "build/release-input")
    parser.add_argument("--output", type=Path, default=ROOT / "build/release-assets")
    args = parser.parse_args()
    try:
        tag = args.tag or ("v" + (ROOT / "VERSION").read_text().strip() if args.dry_run else "")
        if args.command == "validate":
            plan = validate(tag, dry_run=args.dry_run)
            (ROOT / "reports").mkdir(exist_ok=True)
            (ROOT / "reports/release-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
            if output := os.environ.get("GITHUB_OUTPUT"):
                with Path(output).open("a", encoding="utf-8") as destination:
                    for key, value in plan.items():
                        destination.write(f"{key}={str(value).lower() if isinstance(value, bool) else value}\n")
            print(json.dumps(plan, indent=2))
        elif args.command == "package":
            source = ROOT / "build/release-export" / args.platform
            package(tag, args.platform, source, ROOT / "build/release-packages" / args.platform, git("rev-parse", "HEAD"))
        elif args.command == "assemble":
            assemble(tag, args.input, args.output, git("rev-parse", "HEAD"))
        else:
            verify_assets(tag, args.input, git("rev-parse", "HEAD"))
        return 0
    except (RuntimeError, OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        print(f"Release validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
