"""Shared local/CI harness: validate, test, and export the Phase 0 project."""

import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"
LOCK = json.loads((ROOT / "tools/toolchain.json").read_text())
ENGINE_ERRORS = re.compile(r"^(?:SCRIPT ERROR|ERROR|USER ERROR):", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
RESULTS: list[dict] = []


def run(name: str, command: list[str], *, timeout: int = 180,
        engine: bool = False, marker: str | None = None) -> str:
    """Fail on engine errors even when Godot returns zero; preserve every log."""
    REPORTS.mkdir(exist_ok=True)
    print(f"[{name}] {' '.join(map(str, command))}", flush=True)
    started = time.monotonic()
    output = ""
    success = False
    try:
        environment = os.environ.copy()
        if engine:
            # Keep editor/runtime user data local to this checkout, including in CI.
            for variable in ("APPDATA", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                local = ROOT / ".tools/user-data" / variable.lower()
                local.mkdir(parents=True, exist_ok=True)
                environment[variable] = str(local)
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                errors="replace", timeout=timeout, check=False, env=environment)
        output = ANSI.sub("", result.stdout)
        print(output, end="", flush=True)
        if result.returncode or (engine and ENGINE_ERRORS.search(output)):
            raise RuntimeError(f"{name} failed (exit {result.returncode}); see reports/{name}.log")
        if marker and marker not in output:
            raise RuntimeError(f"{name} did not reach required marker: {marker}")
        success = True
        return output
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"")
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        raise RuntimeError(f"{name} timed out after {timeout}s") from error
    finally:
        (REPORTS / f"{name}.log").write_text(output, encoding="utf-8")
        RESULTS.append({"name": name, "passed": success,
                        "duration_seconds": round(time.monotonic() - started, 3)})


def godot() -> str:
    asset = LOCK["godot"][platform.system()]["asset"]
    name = asset.removesuffix(".zip")
    if platform.system() == "Windows":
        name = name.removesuffix(".exe") + "_console.exe"
    path = ROOT / ".tools/godot" / name
    if not path.exists():
        raise RuntimeError("Toolchain missing; run python tools/bootstrap.py --templates")
    return str(path)


def engine_run(name: str, args: list[str], **kwargs: object) -> str:
    return run(name, [godot(), "--headless", "--path", str(ROOT), *args], engine=True, **kwargs)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def metadata(build_type: str = "development", tag: str = "") -> dict:
    version = (ROOT / "VERSION").read_text().strip()
    project = (ROOT / "project.godot").read_text()
    if f'config/version="{version}"' not in project:
        raise RuntimeError("project.godot config/version must match VERSION")
    if build_type not in ("development", "release"):
        raise RuntimeError("Unknown build type")
    if build_type == "release" and (tag != "v" + version or
                                    not re.fullmatch(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", tag)):
        raise RuntimeError("Release export requires a matching semantic version tag")
    engine_version = run("engine-version", [godot(), "--version"]).strip()
    if not engine_version.startswith(LOCK["godot_version"] + ".stable."):
        raise RuntimeError(f"Incorrect engine version: {engine_version}")
    data = {
        "version": version,
        "commit_sha": git("rev-parse", "HEAD"),
        "branch": os.environ.get("GITHUB_HEAD_REF") or os.environ.get("GITHUB_REF_NAME")
                  or git("branch", "--show-current"),
        "engine_version": engine_version,
        "build_id": ".".join([os.environ.get("GITHUB_RUN_NUMBER", "local"),
                              os.environ.get("GITHUB_RUN_ATTEMPT", "1")]),
        "build_type": build_type,
        "ci_run_id": os.environ.get("GITHUB_RUN_ID", "local"),
        "dirty": bool(git("status", "--porcelain")),
    }
    if build_type == "release":
        if data["dirty"]:
            raise RuntimeError("Release export requires a clean working tree")
        data["tag"] = tag
    target = ROOT / "game/core/utilities/build_metadata.json"
    target.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    REPORTS.mkdir(exist_ok=True)
    (REPORTS / "build-metadata.json").write_text(target.read_text(), encoding="utf-8")
    return data


def check_style() -> None:
    files = sorted(str(path.relative_to(ROOT)) for directory in ("game", "tests", "tools")
                   for path in (ROOT / directory).rglob("*.gd"))
    run("format", [sys.executable, "-m", "gdtoolkit.formatter", "--check", *files])
    run("lint", [sys.executable, "-m", "gdtoolkit.linter", *files])


def import_project() -> None:
    engine_run("import", ["--editor", "--import"], timeout=300)


def test_suite(suite: str) -> None:
    report = REPORTS / f"{suite}.xml"
    report.unlink(missing_ok=True)
    engine_run(suite, ["--script", "addons/gut/gut_cmdln.gd", "-gconfig=",
                      f"-gdir=res://tests/{suite}", "-ginclude_subdirs", "-gexit",
                      "-gdisable_colors", f"-gjunit_xml_file={report}"], timeout=300)
    verify_junit(report)


def verify_junit(path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Test runner did not produce {path}")
    root = ET.parse(path).getroot()
    cases = list(root.iter("testcase"))
    if not cases or any(list(root.iter(tag)) for tag in ("failure", "error", "skipped")):
        raise RuntimeError(f"Empty, failed, or pending test suite: {path}")


def determinism() -> None:
    test_suite("determinism")
    samples = []
    for index in range(2):
        output = engine_run(f"seed-process-{index}", ["--script", "tests/fixtures/seed_probe.gd"],
                            marker="DETERMINISM_PROBE=")
        samples.append(json.loads(next(line.split("=", 1)[1] for line in output.splitlines()
                                       if line.startswith("DETERMINISM_PROBE="))))
    if samples[0] != samples[1] or len(samples[0]) != 16:
        raise RuntimeError("Independent seeded fixture processes diverged")
    run_samples = []
    for index in range(2):
        args = ["--script", "tests/fixtures/run_probe.gd"]
        if index == 1:
            args.extend(["--", "--reverse-item-load"])
        output = engine_run(f"run-process-{index}", args,
                            marker="RUN_CHOICES_PROBE=")
        run_samples.append(json.loads(next(line.split("=", 1)[1] for line in output.splitlines()
                                           if line.startswith("RUN_CHOICES_PROBE="))))
    verify_run_samples(run_samples)
    room_samples = []
    for index in range(2):
        args = ["--script", "tests/fixtures/room_run_probe.gd"]
        if index == 1:
            args.extend(["--", "--reverse-item-load"])
        output = engine_run(f"room-run-process-{index}", args, marker="ROOM_RUN_PROBE=")
        room_samples.append(json.loads(next(line.split("=", 1)[1] for line in output.splitlines()
                                           if line.startswith("ROOM_RUN_PROBE="))))
    verify_room_samples(room_samples)
    boss_samples = []
    for index in range(2):
        args = ["--script", "tests/fixtures/boss_run_probe.gd"]
        if index == 1:
            args.extend(["--", "--reverse-item-load"])
        output = engine_run(f"boss-run-process-{index}", args, marker="BOSS_RUN_PROBE=")
        boss_samples.append(json.loads(next(line.split("=", 1)[1] for line in output.splitlines()
                                           if line.startswith("BOSS_RUN_PROBE="))))
    verify_boss_samples(boss_samples)
    (REPORTS / "determinism.json").write_text(json.dumps({"seed": 12345, "draws": samples[0],
                                                         "processes_match": True,
                                                         "run_choices": run_samples[0],
                                                         "run_processes_match": True,
                                                         "room_run": room_samples[0],
                                                         "room_processes_match": True,
                                                         "boss_run": boss_samples[0],
                                                         "boss_processes_match": True}, indent=2) + "\n")


def verify_boss_samples(samples: list) -> None:
    if len(samples) != 2 or samples[0] != samples[1] or not isinstance(samples[0], dict):
        raise RuntimeError("Independent boss run processes diverged")
    record = samples[0]
    if (record.get("rooms") != ["prototype_start", "prototype_combat", "prototype_treasure", "prototype_boss_encounter"]
            or any(record.get(key) is not True for key in ("boss_spawned", "exit_locked", "awaited_boss_choice", "floor_complete"))
            or record.get("items_before_boss") != 1
            or record.get("restart") != {"room": "prototype_start", "draw_count": 0, "items": 0,
                 "health": 100, "magazine": 12, "reserve": 240, "boss_clear": True, "supply_clear": True}):
        raise RuntimeError("Incomplete boss route, reward gate or restart")
    rolls = record.get("drop_rolls")
    if (not isinstance(rolls, list) or len(rolls) != 2 or any(type(kind) is not int or kind not in (-1, 0, 1) for kind in rolls)
            or record.get("draw_count") != 63 + sum(kind != -1 for kind in rolls)):
        raise RuntimeError("Invalid room-clear supply rolls or RNG consumption")
    offers = record.get("offers", [])
    if (not isinstance(offers, list) or len(offers) != 2 or not all(isinstance(offer, dict) for offer in offers)
            or [offer.get("room") for offer in offers] != ["prototype_treasure", "prototype_boss_encounter"]):
        raise RuntimeError("Items must come only from treasure and boss rooms")
    for offer in offers:
        choices = offer.get("choices", [])
        if not isinstance(choices, list) or len(choices) != 3 or not all(isinstance(item, str) for item in choices) or len(set(choices)) != 3:
            raise RuntimeError("Incomplete boss route item offer")
    treasure, boss = offers[0]["choices"][0], offers[1]["choices"][0]
    if (treasure in offers[1]["choices"] or record.get("build") != sorted([treasure, boss])
            or record.get("rewards") != [{"player": 1, "item": boss, "source_player": 1,
                                          "weapon": "pistol", "entity_matches": True}]):
        raise RuntimeError("Invalid boss item ownership or duplicate acquisition")


def verify_room_samples(samples: list) -> None:
    """Require matching complete production routes and a clean whole-run restart."""
    if len(samples) != 2 or samples[0] != samples[1] or not isinstance(samples[0], dict):
        raise RuntimeError("Independent room run processes diverged")
    record = samples[0]
    if (record.get("rooms") != ["prototype_start", "prototype_combat", "prototype_treasure", "prototype_boss"]
            or record.get("completed") is not True or record.get("draw_count") != 64
            or record.get("restart") != {"room": "prototype_start", "draw_count": 0, "items": 0,
                                         "health": 100, "magazine": 12, "reserve": 240}):
        raise RuntimeError("Incomplete room route or stale restart state")
    build = record.get("build")
    if not isinstance(build, list) or len(build) != 5 or len(set(build)) != 5 or build != sorted(build):
        raise RuntimeError("Incomplete room run build")
    verify_run_samples([record.get("waves"), record.get("waves")])


def verify_run_samples(samples: list) -> None:
    """Require complete, matching five-wave production rolls, not an empty probe."""
    if len(samples) != 2 or samples[0] != samples[1]:
        raise RuntimeError("Independent authoritative run processes diverged")
    records = samples[0]
    if not isinstance(records, list) or len(records) != 5:
        raise RuntimeError("Incomplete authoritative run probe")
    acquired = set()
    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise RuntimeError("Invalid authoritative run record")
        spawns = record.get("spawn_order", [])
        choices = record.get("choices", [])
        if (record.get("wave") != index + 1 or not isinstance(spawns, list)
                or sorted(spawns) != list(range(12))
                or not isinstance(choices, list) or not all(isinstance(item, str) for item in choices)
                or len(choices) != (3, 3, 3, 2, 0)[index] or len(set(choices)) != len(choices)
                or acquired.intersection(choices)
                or record.get("draw_count") != (25, 39, 52, 64, 64)[index]):
            raise RuntimeError("Invalid authoritative encounter/reward rolls")
        if choices:
            acquired.add(choices[0])
        if record.get("build_order") != sorted(acquired):
            raise RuntimeError("Invalid authoritative build ordering")


def content() -> None:
    engine_run("content", ["--script", "tools/validate_content.gd"], marker="CONTENT_VALIDATION_OK")


def smoke() -> None:
    engine_run("smoke", ["--", "--smoke"], marker="DEAD_CIRCUIT_READY")


def harness_tests() -> None:
    run("harness", [sys.executable, "-m", "pytest", "tests/harness", "-q",
                    "--basetemp=reports/pytest-tmp", "--junitxml=reports/harness.xml"])


def verify_export_manifest(output: str) -> None:
    paths = re.findall(r"Storing File: (res://\S+)", output)
    forbidden = ("tests/", "tools/", "addons/", "docs/", ".github/", "reports/", "build/", ".gutconfig.json")
    if any(path.removeprefix("res://").startswith(forbidden) for path in paths):
        raise RuntimeError("Development-only files leaked into the export")
    if "res://game/core/utilities/build_metadata.json" not in paths:
        raise RuntimeError("Build provenance was not included in the export")


def export_builds(target: str, build_type: str = "development", tag: str = "") -> None:
    data = metadata(build_type, tag)
    import_project()
    for name in ("windows", "linux") if target == "all" else (target,):
        directory = ROOT / "build" / ("release-export" if build_type == "release" else "") / name
        directory.mkdir(parents=True, exist_ok=True)
        binary = directory / ("DeadCircuit.exe" if name == "windows" else "DeadCircuit.x86_64")
        preset = ("Windows" if name == "windows" else "Linux") + (" Release" if build_type == "release" else " Development")
        mode = "--export-release" if build_type == "release" else "--export-debug"
        output = engine_run(f"export-{name}", ["--editor", mode, preset, str(binary)], timeout=600)
        verify_export_manifest(output)
        if not binary.exists() or binary.stat().st_size == 0:
            raise RuntimeError(f"Export missing: {binary}")
        native = name == ("windows" if platform.system() == "Windows" else "linux")
        if native:
            run(f"export-smoke-{name}", [str(binary), "--headless", "--", "--smoke"],
                engine=True, marker="DEAD_CIRCUIT_READY")
        provenance = {**data, "platform": name, "native_smoke_passed": native}
        (directory / "build-metadata.json").write_text(json.dumps(provenance, indent=2) + "\n")
        checksums = [f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}"
                     for path in sorted(directory.iterdir()) if path.name != "SHA256SUMS.txt"]
        (directory / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("validate", "checks", "tests", "determinism", "content",
                                            "smoke", "import", "style", "metadata", "export"))
    parser.add_argument("--platform", choices=("windows", "linux", "all"), default="all")
    parser.add_argument("--build-type", choices=("development", "release"), default="development")
    parser.add_argument("--tag", default="")
    args = parser.parse_args()
    successful = False
    failure = None
    try:
        if args.command == "export":
            export_builds(args.platform, args.build_type, args.tag)
        elif args.command == "style":
            check_style()
        else:
            metadata()
            if args.command in ("validate", "checks", "import", "tests", "determinism", "content", "smoke"):
                import_project()
            if args.command in ("validate", "checks"):
                check_style()
                harness_tests()
                content()
                smoke()
            if args.command in ("validate", "tests"):
                for suite in ("unit", "integration", "gameplay"):
                    test_suite(suite)
                determinism()
            elif args.command == "determinism":
                determinism()
            elif args.command == "content":
                content()
            elif args.command == "smoke":
                smoke()
        successful = True
        return 0
    except (RuntimeError, OSError, ET.ParseError, subprocess.CalledProcessError) as error:
        failure = str(error)
        print(str(error), file=sys.stderr)
        return 1
    finally:
        REPORTS.mkdir(exist_ok=True)
        summary = {"command": args.command, "passed": successful, "failure": failure, "steps": RESULTS}
        (REPORTS / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
        if destination := os.environ.get("GITHUB_STEP_SUMMARY"):
            with Path(destination).open("a", encoding="utf-8") as output:
                output.write(f"### Dead Circuit {args.command}: {'passed' if successful else 'failed'}\n\n")
                output.write("| Step | Result | Seconds |\n| --- | --- | --- |\n")
                for result in RESULTS:
                    output.write(f"| {result['name']} | {'pass' if result['passed'] else 'fail'} | {result['duration_seconds']} |\n")
                if failure:
                    output.write(f"\nFailure: {failure}\n")


if __name__ == "__main__":
    sys.exit(main())
