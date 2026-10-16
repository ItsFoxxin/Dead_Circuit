"""Preserve debug defaults and require the real native smoke path for exports."""

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[2] / "tools"))
import dev


@pytest.fixture
def exporter(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(dev, "ROOT", tmp_path)
    monkeypatch.setattr(dev, "metadata", lambda mode, tag: {"build_type": mode, "tag": tag})
    monkeypatch.setattr(dev, "import_project", lambda: None)

    def engine(name, args, **kwargs):
        calls.append((name, args))
        Path(args[-1]).write_bytes(b"export fixture")
        return "Storing File: res://game/core/utilities/build_metadata.json\n"

    def smoke(name, args, **kwargs):
        calls.append((name, args))
        assert kwargs == {"engine": True, "marker": "DEAD_CIRCUIT_READY"}
        return "DEAD_CIRCUIT_READY"

    monkeypatch.setattr(dev, "engine_run", engine)
    monkeypatch.setattr(dev, "run", smoke)
    return tmp_path, calls


def test_default_development_export_uses_original_preset_and_native_smoke(exporter, monkeypatch):
    root, calls = exporter
    monkeypatch.setattr(dev.platform, "system", lambda: "Windows")
    dev.export_builds("windows")
    assert calls[0][1][1:3] == ["--export-debug", "Windows Development"]
    assert Path(calls[0][1][-1]) == root / "build/windows/DeadCircuit.exe"
    assert calls[1][0] == "export-smoke-windows"
    assert (root / "build/windows/SHA256SUMS.txt").exists()


def test_release_export_uses_release_template_and_records_native_pass(exporter, monkeypatch):
    root, calls = exporter
    monkeypatch.setattr(dev.platform, "system", lambda: "Linux")
    dev.export_builds("linux", "release", "v0.0.2")
    assert calls[0][1][1:3] == ["--export-release", "Linux Release"]
    assert calls[1][0] == "export-smoke-linux"
    data = json.loads((root / "build/release-export/linux/build-metadata.json").read_text())
    assert data["build_type"] == "release"
    assert data["native_smoke_passed"] is True
    assert data["platform"] == "linux"


def test_cross_export_cannot_claim_native_startup(exporter, monkeypatch):
    root, calls = exporter
    monkeypatch.setattr(dev.platform, "system", lambda: "Windows")
    dev.export_builds("linux", "release", "v0.0.2")
    assert len(calls) == 1
    data = json.loads((root / "build/release-export/linux/build-metadata.json").read_text())
    assert data["native_smoke_passed"] is False


def test_failed_native_startup_does_not_complete_export_checksums(exporter, monkeypatch):
    root, _ = exporter
    monkeypatch.setattr(dev.platform, "system", lambda: "Windows")

    def fail(*args, **kwargs):
        raise RuntimeError("native startup failed")

    monkeypatch.setattr(dev, "run", fail)
    with pytest.raises(RuntimeError, match="native startup failed"):
        dev.export_builds("windows", "release", "v0.0.2")
    assert not (root / "build/release-export/windows/SHA256SUMS.txt").exists()
