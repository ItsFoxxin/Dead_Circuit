"""The manual publish action must approve main history before writing a tag."""
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
import yaml

sys.path.insert(0, str(Path(__file__).parents[2] / "tools"))
import prepare_release

SHA = "a" * 40


@pytest.fixture
def approval(monkeypatch):
    calls = []
    existing = {"release": None, "tag": None}
    def git(*args):
        return SHA if args[0] == "rev-parse" else "0.0.2" if args[1].endswith(":VERSION") else '[application]\nconfig/version="0.0.2"\n'
    def api(repo, path, **kwargs):
        calls.append((path, kwargs))
        if path.startswith("releases/"):
            return existing["release"]
        if path.startswith("git/ref/tags/"):
            return existing["tag"]
        return {"sha": "b" * 40}
    monkeypatch.setattr(prepare_release.release, "git", git)
    monkeypatch.setattr(prepare_release.subprocess, "run", lambda *args, **kwargs: SimpleNamespace(returncode=0))
    monkeypatch.setattr(prepare_release.publish_release, "api", api)
    monkeypatch.setattr(prepare_release.publish_release, "verify_remote_tag", lambda *args: None)
    return calls, existing


def test_approved_main_version_creates_annotated_tag_and_ref(approval):
    calls, _ = approval
    assert prepare_release.prepare("owner/repo", "v0.0.2", SHA)["commit"] == SHA
    assert calls[-2][0] == "git/tags" and calls[-2][1]["payload"]["object"] == SHA
    assert calls[-1][1]["payload"]["ref"] == "refs/tags/v0.0.2"


@pytest.mark.parametrize("tag,sha", [("v00.0.2", SHA), ("v0.0.3", SHA), ("v0.0.2", "main")])
def test_bad_approval_never_writes(tag, sha, approval):
    calls, _ = approval
    with pytest.raises(RuntimeError):
        prepare_release.prepare("owner/repo", tag, sha)
    assert not any(kwargs.get("method") == "POST" for _, kwargs in calls)


def test_commit_outside_main_never_writes(approval, monkeypatch):
    calls, _ = approval
    monkeypatch.setattr(prepare_release.subprocess, "run", lambda *args, **kwargs: SimpleNamespace(returncode=1))
    with pytest.raises(RuntimeError, match="origin/main"):
        prepare_release.prepare("owner/repo", "v0.0.2", SHA)
    assert calls == []


def test_existing_release_is_preserved(approval):
    calls, existing = approval
    existing["release"] = {"draft": True}
    with pytest.raises(RuntimeError, match="already exists"):
        prepare_release.prepare("owner/repo", "v0.0.2", SHA)
    assert not any(kwargs.get("method") == "POST" for _, kwargs in calls)


def test_matching_tag_retry_does_not_rewrite_tag(approval):
    calls, existing = approval
    existing["tag"] = {"object": {"sha": SHA, "type": "commit"}}
    assert prepare_release.prepare("owner/repo", "v0.0.2", SHA)["existing_matching_tag"]
    assert not any(kwargs.get("method") == "POST" for _, kwargs in calls)


def test_moved_tag_fails(approval, monkeypatch):
    _, existing = approval
    existing["tag"] = {"object": {"sha": "b" * 40, "type": "commit"}}
    def moved(*args):
        raise RuntimeError("Remote tag moved")
    monkeypatch.setattr(prepare_release.publish_release, "verify_remote_tag", moved)
    with pytest.raises(RuntimeError, match="moved"):
        prepare_release.prepare("owner/repo", "v0.0.2", SHA)


def test_manual_workflow_preserves_native_gates_and_explicit_source_checkout():
    root = Path(__file__).parents[2] / ".github/workflows"
    load = lambda name: yaml.load((root / name).read_text(), Loader=yaml.BaseLoader)
    workflow = load("publish-main.yml")
    assert set(workflow["on"]) == {"workflow_dispatch"}
    assert workflow["permissions"] == {"contents": "read"}
    assert workflow["jobs"]["prepare"]["if"] == "github.ref == 'refs/heads/main'"
    assert workflow["jobs"]["gates"]["with"]["dry-run"] == "false"
    assert set(workflow["jobs"]["publish"]["needs"]) == {"prepare", "gates"}
    publish_steps = workflow["jobs"]["publish"]["steps"]
    assert publish_steps[0]["with"]["ref"] == "${{ github.sha }}"
    assert publish_steps[0]["with"]["path"] == "release-tooling"
    assert publish_steps[1]["with"]["ref"] == "${{ needs.prepare.outputs.commit }}"
    assert publish_steps[1]["with"]["path"] == "release-source"
    assert "--approved-commit" in publish_steps[-1]["run"]
    assert "--source-root release-source" in publish_steps[-1]["run"]
    for job in ("prepare", "publish"):
        assert workflow["jobs"][job]["permissions"] == {"contents": "write"}
    foundation = load("foundation.yml")
    assert foundation["on"]["workflow_call"]["inputs"]["source-ref"]["default"] == ""
    for job in ("validation", "tests", "development-builds"):
        assert foundation["jobs"][job]["steps"][0]["with"]["ref"] == "${{ inputs.source-ref || github.sha }}"
    gates = load("release-gates.yml")
    assert gates["jobs"]["foundation"]["with"]["source-ref"] == "${{ inputs.source-ref }}"
