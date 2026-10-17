"""Failure-path coverage for the harness, which must never report false success."""

import importlib.util
import copy
import sys
from pathlib import Path

import pytest

SPEC = importlib.util.spec_from_file_location("dev", Path(__file__).parents[2] / "tools/dev.py")
dev = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dev)


@pytest.fixture(autouse=True)
def isolated_reports(tmp_path, monkeypatch):
    monkeypatch.setattr(dev, "REPORTS", tmp_path)
    monkeypatch.setattr(dev, "RESULTS", [])


def test_engine_error_fails_even_with_zero_exit():
    with pytest.raises(RuntimeError, match="failed"):
        dev.run("bad-engine", [sys.executable, "-c", "print('SCRIPT ERROR: parse failed')"], engine=True)


def test_colored_engine_error_fails():
    with pytest.raises(RuntimeError, match="failed"):
        dev.run("colored-error", [sys.executable, "-c", "print('\\x1b[31mERROR: failed\\x1b[0m')"], engine=True)


def test_missing_smoke_marker_fails():
    with pytest.raises(RuntimeError, match="marker"):
        dev.run("bad-smoke", [sys.executable, "-c", "print('exited early')"], marker="READY")


def test_nonzero_exit_fails():
    with pytest.raises(RuntimeError, match="exit 7"):
        dev.run("bad-exit", [sys.executable, "-c", "raise SystemExit(7)"])


@pytest.mark.parametrize("xml", ["<testsuites/>", '<testsuite><testcase><skipped/></testcase></testsuite>',
                                  '<testsuite><testcase><failure/></testcase></testsuite>'])
def test_empty_pending_or_failed_reports_fail(tmp_path, xml):
    path = tmp_path / "test.xml"
    path.write_text(xml)
    with pytest.raises(RuntimeError):
        dev.verify_junit(path)


def test_missing_test_report_fails(tmp_path):
    with pytest.raises(RuntimeError, match="did not produce"):
        dev.verify_junit(tmp_path / "missing.xml")


def test_export_without_provenance_fails():
    with pytest.raises(RuntimeError, match="provenance"):
        dev.verify_export_manifest("Storing File: res://game/core/bootstrap.gdc")


@pytest.mark.parametrize("path", ["tests/unit/test.gdc", "reports/build-metadata.json",
                                  "build/windows/build-metadata.json", "addons/gut/gut.gdc"])
def test_development_files_cannot_leak_into_export(path):
    output = "Storing File: res://game/core/utilities/build_metadata.json\nStoring File: res://" + path
    with pytest.raises(RuntimeError, match="leaked"):
        dev.verify_export_manifest(output)


def run_probe_fixture():
    choices = [["a", "b", "c"], ["b", "c", "d"], ["c", "d", "e"], ["d", "e"], []]
    return [{"wave": index + 1, "spawn_order": list(range(12)), "choices": choices[index],
             "build_order": list("abcd"[:min(index + 1, 4)]),
             "draw_count": (25, 39, 52, 64, 64)[index]} for index in range(5)]


def test_complete_matching_production_run_probes_pass():
    records = run_probe_fixture()
    dev.verify_run_samples([records, copy.deepcopy(records)])


def test_production_run_process_divergence_fails():
    records = run_probe_fixture()
    changed = copy.deepcopy(records)
    changed[0]["spawn_order"].reverse()
    with pytest.raises(RuntimeError, match="diverged"):
        dev.verify_run_samples([records, changed])


@pytest.mark.parametrize("failure", ["empty", "missing-wave", "duplicate-spawn", "owned-item",
                                     "duplicate-choice", "no-draws", "missing-choices", "build-order"])
def test_incomplete_or_invalid_production_run_probe_fails(failure):
    records = run_probe_fixture()
    if failure == "empty":
        records = []
    elif failure == "missing-wave":
        records.pop()
    elif failure == "duplicate-spawn":
        records[0]["spawn_order"][1] = 0
    elif failure == "owned-item":
        records[1]["choices"][0] = "a"
    elif failure == "duplicate-choice":
        records[0]["choices"][1] = "a"
    elif failure == "no-draws":
        records[0]["draw_count"] = 0
    elif failure == "build-order":
        records[1]["build_order"].reverse()
    else:
        del records[0]["choices"]
    with pytest.raises(RuntimeError, match="Incomplete|Invalid"):
        dev.verify_run_samples([records, copy.deepcopy(records)])


def room_probe_fixture():
    return {"rooms": ["prototype_start", "prototype_combat", "prototype_treasure", "prototype_boss"],
            "waves": run_probe_fixture(), "completed": True, "draw_count": 64,
            "build": list("abcde"), "restart": {"room": "prototype_start", "draw_count": 0,
                "items": 0, "health": 100, "magazine": 12, "reserve": 240}}


def test_complete_matching_room_routes_and_clean_restart_pass():
    record = room_probe_fixture()
    dev.verify_room_samples([record, copy.deepcopy(record)])


@pytest.mark.parametrize("failure", ["diverged", "missing-room", "incomplete", "stale-build",
                                     "stale-ammo", "rng-reset", "missing-wave", "missing-item"])
def test_incomplete_room_routes_or_leaked_restart_state_fail(failure):
    record = room_probe_fixture()
    if failure == "diverged":
        changed = copy.deepcopy(record)
        changed["waves"][0]["spawn_order"].reverse()
        with pytest.raises(RuntimeError, match="diverged"):
            dev.verify_room_samples([record, changed])
        return
    if failure == "missing-room":
        record["rooms"].pop()
    elif failure == "incomplete":
        record["completed"] = False
    elif failure == "stale-build":
        record["restart"]["items"] = 1
    elif failure == "stale-ammo":
        record["restart"]["magazine"] = 11
    elif failure == "rng-reset":
        record["draw_count"] = 0
    elif failure == "missing-wave":
        record["waves"].pop()
    else:
        record["build"].pop()
    with pytest.raises(RuntimeError, match="Incomplete"):
        dev.verify_room_samples([record, copy.deepcopy(record)])


def boss_probe_fixture():
    return {"rooms": ["prototype_start", "prototype_combat", "prototype_treasure", "prototype_boss_encounter"],
            "boss_spawned": True, "exit_locked": True, "awaited_boss_choice": True, "floor_complete": True,
            "items_before_boss": 1, "draw_count": 64, "drop_rolls": [-1, 1], "build": ["a", "d"],
            "offers": [{"room": "prototype_treasure", "choices": ["a", "b", "c"]},
                       {"room": "prototype_boss_encounter", "choices": ["d", "b", "e"]}],
            "rewards": [{"player": 1, "item": "d", "source_player": 1, "weapon": "pistol", "entity_matches": True}],
            "restart": {"room": "prototype_start", "draw_count": 0, "items": 0, "health": 100,
                        "magazine": 12, "reserve": 240, "boss_clear": True, "supply_clear": True}}


def test_complete_matching_two_item_boss_runs_pass():
    record = boss_probe_fixture()
    dev.verify_boss_samples([record, copy.deepcopy(record)])


@pytest.mark.parametrize("failure", ["missing-boss", "early-exit", "per-wave-items", "missing-offer",
                                     "owned-choice", "wrong-owner", "extra-draw", "stale-boss", "bad-drop"])
def test_incomplete_boss_runs_or_excessive_rewards_fail(failure):
    record = boss_probe_fixture()
    if failure == "missing-boss":
        record["boss_spawned"] = False
    elif failure == "early-exit":
        record["awaited_boss_choice"] = False
    elif failure == "per-wave-items":
        record["items_before_boss"] = 5
    elif failure == "missing-offer":
        record["offers"].pop()
    elif failure == "owned-choice":
        record["offers"][1]["choices"][1] = "a"
    elif failure == "wrong-owner":
        record["rewards"][0]["source_player"] = 22
    elif failure == "extra-draw":
        record["draw_count"] += 1
    elif failure == "stale-boss":
        record["restart"]["boss_clear"] = False
    else:
        record["drop_rolls"][0] = True
    with pytest.raises(RuntimeError):
        dev.verify_boss_samples([record, copy.deepcopy(record)])
