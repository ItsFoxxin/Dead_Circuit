"""Failure-path coverage for the harness, which must never report false success."""

import importlib.util
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
