"""Release approval and packaging failures must prevent publication."""

import json
import os
import stat
import subprocess
import sys
import zipfile
from pathlib import Path

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parents[2] / "tools"))
import release

REPO = Path(__file__).parents[2]
SHA = "a" * 40


@pytest.mark.parametrize("tag,pre", [("v0.0.2", True), ("v0.1.0", True), ("v1.0.0", False), ("v2.12.3", False)])
def test_version_and_prerelease_policy(tag, pre):
    assert release.tag_version(tag) == (tag[1:], pre)


@pytest.mark.parametrize("tag", ["0.0.2", "v01.0.0", "v0.00.1", "v1.2", "v1.2.3.4",
                                 "v1.2.3-rc.1", "v1.2.3+build", "v-1.0.0", "v1.2.3\n", "vbad"])
def test_malformed_tags_fail(tag):
    with pytest.raises(RuntimeError):
        release.tag_version(tag)


@pytest.fixture
def repository(tmp_path, monkeypatch):
    root = tmp_path / "repository"
    root.mkdir()
    monkeypatch.setattr(release, "ROOT", root)

    def git(*args):
        return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()

    git("init", "-b", "main")
    git("config", "user.name", "Release Test")
    git("config", "user.email", "release-test@example.invalid")
    (root / "VERSION").write_text("1.2.3\n")
    (root / "project.godot").write_text('[application]\nconfig/version="1.2.3"\n')
    git("add", ".")
    git("commit", "-m", "Accepted fixture")
    git("update-ref", "refs/remotes/origin/main", "HEAD")
    git("tag", "-a", "v1.2.3", "-m", "Accepted fixture")
    return root, git


def test_annotated_tag_on_main_is_accepted(repository):
    assert release.validate("v1.2.3")["commit_sha"] == repository[1]("rev-parse", "HEAD")


@pytest.mark.parametrize("file,text", [
    ("VERSION", "1.2.4\n"),
    ("project.godot", '[application]\nconfig/version="1.2.4"\n'),
    ("project.godot", '[other]\nconfig/version="1.2.3"\n'),
    ("project.godot", '[application]\n; config/version="1.2.3"\n'),
    ("project.godot", '[application]\nconfig/version="1.2.3"\n[application]\nconfig/version="1.2.4"\n')])
def test_mismatched_or_missing_version_fails(repository, file, text):
    (repository[0] / file).write_text(text)
    with pytest.raises(RuntimeError, match="version"):
        release.validate("v1.2.3")


def test_feature_branch_tag_cannot_be_released(repository):
    root, git = repository
    (root / "feature.txt").write_text("unaccepted")
    git("add", ".")
    git("commit", "-m", "Unaccepted fixture")
    git("tag", "-f", "v1.2.3")
    with pytest.raises(RuntimeError, match="not reachable"):
        release.validate("v1.2.3")
    assert release.validate("v1.2.3", dry_run=True)["dry_run"] is True


def test_checkout_must_equal_the_tagged_commit(repository):
    root, git = repository
    (root / "other.txt").write_text("other")
    git("add", ".")
    git("commit", "-m", "Other fixture")
    with pytest.raises(RuntimeError, match="not the tagged"):
        release.validate("v1.2.3")


@pytest.fixture
def exports(tmp_path, monkeypatch):
    monkeypatch.setenv("GITHUB_RUN_ID", "test-run")
    paths = {}
    for platform, binary in release.PLATFORMS.items():
        directory = tmp_path / platform
        directory.mkdir()
        (directory / binary).write_bytes(b"fixture binary, not executable")
        data = {"version": "0.0.2", "tag": "v0.0.2", "commit_sha": SHA,
                "engine_version": "4.7.2.stable.official.fixture", "build_type": "release",
                "platform": platform, "dirty": False, "native_smoke_passed": True,
                "build_id": "123.1", "ci_run_id": "test-run"}
        (directory / "build-metadata.json").write_text(json.dumps(data))
        _checksums(directory)
        paths[platform] = directory
    return paths


def _checksums(directory):
    (directory / "SHA256SUMS.txt").write_text("".join(
        f"{release.digest(path)}  {path.name}\n" for path in sorted(directory.iterdir())
        if path.name != "SHA256SUMS.txt"))


def _packages(exports, destination):
    for platform, directory in exports.items():
        release.package("v0.0.2", platform, directory, destination, SHA)


def test_packages_have_predictable_names_metadata_checksums_and_linux_mode(exports, tmp_path):
    destination = tmp_path / "packages"
    _packages(exports, destination)
    output = tmp_path / "assets"
    release.assemble("v0.0.2", destination, output, SHA)
    assert len(list(output.iterdir())) == 4
    assert release.verify_assets("v0.0.2", output, SHA)["prerelease"] is True
    with zipfile.ZipFile(destination / release.archive_name("v0.0.2", "linux")) as archive:
        mode = archive.getinfo("DeadCircuit.x86_64").external_attr >> 16
        assert stat.S_ISREG(mode) and mode & 0o111


@pytest.mark.parametrize("key,value", [("version", "0.0.3"), ("tag", "v0.0.3"),
    ("commit_sha", "b" * 40), ("dirty", True), ("native_smoke_passed", False),
    ("build_type", "development"), ("engine_version", "4.6.stable"), ("build_id", "")])
def test_wrong_provenance_or_missing_native_smoke_fails(exports, tmp_path, key, value):
    source = exports["windows"]
    data = json.loads((source / "build-metadata.json").read_text())
    data[key] = value
    (source / "build-metadata.json").write_text(json.dumps(data))
    _checksums(source)
    with pytest.raises(RuntimeError):
        release.package("v0.0.2", "windows", source, tmp_path / "packages", SHA)


def test_missing_checksum_file_fails(exports, tmp_path):
    (exports["windows"] / "SHA256SUMS.txt").unlink()
    with pytest.raises(RuntimeError):
        release.package("v0.0.2", "windows", exports["windows"], tmp_path / "packages", SHA)


def test_changed_binary_fails_checksum_verification(exports, tmp_path):
    (exports["windows"] / "DeadCircuit.exe").write_bytes(b"changed")
    with pytest.raises(RuntimeError, match="checksum"):
        release.package("v0.0.2", "windows", exports["windows"], tmp_path / "packages", SHA)


def test_missing_platform_and_cross_run_packages_fail(exports, tmp_path, monkeypatch):
    destination = tmp_path / "packages"
    release.package("v0.0.2", "windows", exports["windows"], destination, SHA)
    with pytest.raises(RuntimeError, match="Both fresh native"):
        release.assemble("v0.0.2", destination, tmp_path / "assets", SHA)
    release.package("v0.0.2", "linux", exports["linux"], destination, SHA)
    monkeypatch.setenv("GITHUB_RUN_ID", "another-run")
    with pytest.raises(RuntimeError, match="this workflow run"):
        release.assemble("v0.0.2", destination, tmp_path / "assets", SHA)


def test_different_native_build_ids_fail(exports, tmp_path):
    source = exports["linux"]
    data = json.loads((source / "build-metadata.json").read_text())
    data["build_id"] = "456.1"
    (source / "build-metadata.json").write_text(json.dumps(data))
    _checksums(source)
    destination = tmp_path / "packages"
    _packages(exports, destination)
    with pytest.raises(RuntimeError, match="different build provenance"):
        release.assemble("v0.0.2", destination, tmp_path / "assets", SHA)


def test_unexpected_zip_members_are_rejected(exports, tmp_path):
    path = release.package("v0.0.2", "linux", exports["linux"], tmp_path / "packages", SHA)
    with zipfile.ZipFile(path, "a") as archive:
        archive.writestr("../unexpected", b"unexpected")
    with pytest.raises(RuntimeError, match="ZIP members"):
        release.verify_package(path, "v0.0.2", "linux", SHA)


def test_tampered_release_assets_fail_before_publication(exports, tmp_path):
    destination = tmp_path / "packages"
    _packages(exports, destination)
    output = tmp_path / "assets"
    release.assemble("v0.0.2", destination, output, SHA)
    (output / "build-metadata.json").write_text("{}")
    with pytest.raises(RuntimeError, match="checksum"):
        release.verify_assets("v0.0.2", output, SHA)


def test_workflow_graph_keeps_publication_after_all_gates_and_permissions_minimal():
    load = lambda name: yaml.load((REPO / ".github/workflows" / name).read_text(), Loader=yaml.BaseLoader)
    workflow = load("release.yml")
    assert workflow["on"]["push"] == {"tags": ["v*"]}
    assert "pull_request" not in workflow["on"]
    assert workflow["permissions"] == {"contents": "read"}
    assert workflow["jobs"]["publish"]["needs"] == "gates"
    assert workflow["jobs"]["publish"]["permissions"] == {"contents": "write"}
    assert "github.event_name == 'push'" in workflow["jobs"]["publish"]["if"]
    assert "github.ref_type == 'tag'" in workflow["jobs"]["publish"]["if"]
    gates = load("release-gates.yml")
    assert set(gates["jobs"]["packages"]["needs"]) == {"approval", "foundation"}
    assert gates["jobs"]["foundation"]["uses"] == "./.github/workflows/foundation.yml"
    assert gates["jobs"]["foundation"]["with"]["build-type"] == "release"
    assert gates["permissions"] == {"contents": "read"}
    ci = load("ci.yml")
    assert ci["on"]["push"]["branches"] == ["dev", "main"]
    assert ci["on"]["pull_request"]["branches"] == ["dev", "main"]
    assert ci["on"]["workflow_dispatch"]["inputs"]["release-dry-run"]["default"] == "false"
