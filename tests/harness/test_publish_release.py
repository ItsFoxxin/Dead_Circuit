"""Exercise duplicate refusal and draft rollback without accessing GitHub."""

import json
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).parents[2] / "tools"))
import publish_release as publisher

SHA = "a" * 40


@pytest.fixture
def publication(tmp_path, monkeypatch):
    for name in ("windows.zip", "linux.zip", "SHA256SUMS.txt", "build-metadata.json"):
        (tmp_path / name).write_bytes(name.encode())
    plan = {"commit_sha": SHA, "prerelease": True}
    monkeypatch.setattr(publisher.release, "validate", lambda tag: plan)
    monkeypatch.setattr(publisher.release, "verify_assets", lambda *args: {"engine_version": "4.7.2.stable.fixture"})
    state = {"calls": [], "existing": None, "upload_fails": False, "asset_missing": False,
             "draft": True, "remote_sha": SHA}

    def api(repo, path, *, method="GET", payload=None, missing_ok=False):
        state["calls"].append((path, method, payload))
        if path.startswith("releases/tags/"):
            return state["existing"]
        if path.startswith("git/ref/"):
            return {"object": {"type": "tag", "sha": "annotation"}}
        if path == "git/tags/annotation":
            return {"object": {"type": "commit", "sha": state["remote_sha"]}}
        if path == "releases/generate-notes":
            return {"body": "## Generated changes\nExact generated notes preserved."}
        if path == "releases" and method == "POST":
            return {"id": 100}
        if path == "releases/100" and method == "GET":
            assets = [{"name": p.name, "size": p.stat().st_size, "state": "uploaded"}
                      for p in tmp_path.iterdir()]
            return {"draft": state["draft"], "assets": assets[:-1] if state["asset_missing"] else assets}
        if method == "PATCH":
            state["draft"] = False
            return {"draft": False, "html_url": "https://example.invalid/release"}
        if method == "DELETE":
            return {}
        raise AssertionError((path, method))

    def upload(*args, **kwargs):
        if state["upload_fails"]:
            raise subprocess.CalledProcessError(1, "gh release upload")
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(publisher, "api", api)
    monkeypatch.setattr(publisher.subprocess, "run", upload)
    return tmp_path, state, plan


@pytest.mark.parametrize("existing", [{"id": 1, "draft": False}, {"id": 2, "draft": True}])
def test_existing_release_is_never_changed(publication, existing):
    directory, state, _ = publication
    state["existing"] = existing
    with pytest.raises(RuntimeError, match="already exists"):
        publisher.publish("owner/repo", "v0.0.1", directory)
    assert all(method == "GET" for _, method, _ in state["calls"])


def test_upload_failure_removes_only_new_draft_not_tag(publication):
    directory, state, _ = publication
    state["upload_fails"] = True
    with pytest.raises(subprocess.CalledProcessError):
        publisher.publish("owner/repo", "v0.0.2", directory)
    assert ("releases/100", "DELETE", None) in state["calls"]
    assert not any(method == "PATCH" for _, method, _ in state["calls"])
    assert not any(path.startswith("git/") and method == "DELETE" for path, method, _ in state["calls"])


def test_missing_uploaded_asset_prevents_publication_and_cleans_draft(publication):
    directory, state, _ = publication
    state["asset_missing"] = True
    with pytest.raises(RuntimeError, match="incomplete"):
        publisher.publish("owner/repo", "v0.0.2", directory)
    assert ("releases/100", "DELETE", None) in state["calls"]
    assert not any(method == "PATCH" for _, method, _ in state["calls"])


@pytest.mark.parametrize("prerelease,latest", [(True, "false"), (False, "legacy")])
def test_all_assets_are_verified_before_publishing_with_correct_policy(publication, prerelease, latest):
    directory, state, plan = publication
    plan["prerelease"] = prerelease
    publisher.publish("owner/repo", "v0.0.2" if prerelease else "v1.0.0", directory)
    create = next(payload for path, method, payload in state["calls"] if path == "releases" and method == "POST")
    assert create["draft"] is True
    assert create["prerelease"] is prerelease
    assert create["make_latest"] == latest
    assert "Exact generated notes preserved." in create["body"]
    assert SHA in create["body"]
    patch = next(payload for _, method, payload in state["calls"] if method == "PATCH")
    assert patch == {"draft": False, "prerelease": prerelease, "make_latest": latest}
    assert not any(method == "DELETE" for _, method, _ in state["calls"])


def test_moved_remote_tag_prevents_creating_release(publication):
    directory, state, _ = publication
    state["remote_sha"] = "b" * 40
    with pytest.raises(RuntimeError, match="Remote tag moved"):
        publisher.publish("owner/repo", "v0.0.2", directory)
    assert not any(method == "POST" for _, method, _ in state["calls"])


def test_workflow_dispatch_cannot_publish(monkeypatch):
    monkeypatch.setenv("GITHUB_EVENT_NAME", "workflow_dispatch")
    monkeypatch.setenv("GITHUB_REF", "refs/heads/main")
    monkeypatch.setattr(sys, "argv", ["publish_release.py", "--tag", "v0.0.2"])
    assert publisher.main() == 1


@pytest.mark.parametrize("status,missing_ok,expected", [(404, True, None), (500, True, RuntimeError),
                                                      (404, False, RuntimeError)])
def test_api_not_found_is_distinguished_from_permission_or_server_failure(monkeypatch, status, missing_ok, expected):
    monkeypatch.setattr(publisher.subprocess, "run", lambda *args, **kwargs:
                        SimpleNamespace(returncode=1, stdout=json.dumps({"status": str(status)}), stderr="failure"))
    if expected is None:
        assert publisher.api("owner/repo", "releases/tags/v0.0.2", missing_ok=missing_ok) is None
    else:
        with pytest.raises(expected):
            publisher.api("owner/repo", "releases/tags/v0.0.2", missing_ok=missing_ok)
