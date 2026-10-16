"""Publish verified assets through GitHub CLI, staging a draft until upload succeeds."""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

import release


def api(repo: str, path: str, *, method: str = "GET", payload: dict | None = None,
        missing_ok: bool = False) -> dict | None:
    command = ["gh", "api", f"repos/{repo}/{path}", "--method", method]
    if payload is not None:
        command.extend(["--input", "-"])
    result = subprocess.run(command, input=json.dumps(payload) if payload is not None else None,
                            text=True, capture_output=True, check=False)
    data = json.loads(result.stdout) if result.stdout.strip() else {}
    if result.returncode:
        if missing_ok and (str(data.get("status")) == "404" or result.stderr.strip().endswith("(HTTP 404)")):
            return None
        raise RuntimeError(f"GitHub API {method} {path} failed: {result.stderr.strip()}")
    return data


def verify_remote_tag(repo: str, tag: str, sha: str) -> None:
    value = api(repo, f"git/ref/tags/{tag}")["object"]
    for _ in range(8):
        if value["type"] != "tag":
            break
        value = api(repo, f"git/tags/{value['sha']}")["object"]
    if value["type"] != "commit" or value["sha"] != sha:
        raise RuntimeError("Remote tag moved or does not refer to the validated commit")


def publish(repo: str, tag: str, directory: Path, *, expected_commit: str = "") -> None:
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo) is None:
        raise RuntimeError("Expected owner/repository")
    plan = release.validate(tag)
    if expected_commit and plan["commit_sha"] != expected_commit:
        raise RuntimeError("Source checkout differs from the explicitly approved commit")
    data = release.verify_assets(tag, directory, plan["commit_sha"])
    if api(repo, f"releases/tags/{tag}", missing_ok=True) is not None:
        raise RuntimeError(f"Release {tag} already exists; refusing to change it or its assets")
    verify_remote_tag(repo, tag, plan["commit_sha"])
    generated = api(repo, "releases/generate-notes", method="POST",
                    payload={"tag_name": tag, "target_commitish": plan["commit_sha"]})
    notes = (f"Dead Circuit {tag}\n\n"
             f"- Commit: {plan['commit_sha']}\n- Godot: {data['engine_version']}\n"
             f"- Builds: Windows x86_64 and Linux x86_64 (native startup smoke passed)\n"
             f"- Status: {'Pre-release (pre-1.0 prototype milestone)' if plan['prerelease'] else 'Stable release'}\n"
             "- See build-metadata.json and SHA256SUMS.txt for provenance and verification.\n\n"
             + generated["body"])
    authored_notes = release.ROOT / "docs/release-notes" / f"{tag}.md"
    if authored_notes.is_file():
        notes = authored_notes.read_text(encoding="utf-8").strip() + "\n\n---\n\n" + notes
    latest = "false" if plan["prerelease"] else "legacy"
    created = api(repo, "releases", method="POST", payload={
        "tag_name": tag, "target_commitish": plan["commit_sha"], "name": f"Dead Circuit {tag}",
        "body": notes, "draft": True, "prerelease": plan["prerelease"], "make_latest": latest})
    release_id = created["id"]
    published = False
    try:
        assets = sorted(directory.iterdir())
        subprocess.run(["gh", "release", "upload", tag, *map(str, assets), "--repo", repo], check=True)
        uploaded = api(repo, f"releases/{release_id}")
        expected = {path.name: path.stat().st_size for path in assets}
        actual = {asset["name"]: asset["size"] for asset in uploaded["assets"]
                  if asset.get("state") == "uploaded"}
        if actual != expected or len(uploaded["assets"]) != len(expected):
            raise RuntimeError("Uploaded release assets are missing or incomplete")
        for asset in uploaded["assets"]:
            if asset.get("digest") and asset["digest"] != "sha256:" + release.digest(directory / asset["name"]):
                raise RuntimeError("Uploaded asset digest differs from the verified package")
        verify_remote_tag(repo, tag, plan["commit_sha"])
        result = api(repo, f"releases/{release_id}", method="PATCH",
                     payload={"draft": False, "prerelease": plan["prerelease"], "make_latest": latest})
        if result.get("draft") is not False:
            raise RuntimeError("Release remained a draft")
        published = True
        print(result["html_url"])
    finally:
        if not published:
            # Only remove this run's still-draft release; never delete tags or historical releases.
            try:
                current = api(repo, f"releases/{release_id}")
                if current.get("draft") is True:
                    api(repo, f"releases/{release_id}", method="DELETE")
            except (RuntimeError, OSError, ValueError) as error:
                print(f"Draft cleanup needs attention for release ID {release_id}: {error}", file=sys.stderr)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--input", type=Path, default=release.ROOT / "build/release-assets")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    parser.add_argument("--approved-commit", default="")
    parser.add_argument("--source-root", type=Path)
    args = parser.parse_args()
    try:
        if args.approved_commit:
            expected_workflow = f"{args.repo}/.github/workflows/publish-main.yml@refs/heads/main"
            if (os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch"
                    or os.environ.get("GITHUB_REF") != "refs/heads/main"
                    or os.environ.get("GITHUB_WORKFLOW_REF") != expected_workflow):
                raise RuntimeError("Explicit publication requires the accepted-main workflow on main")
            event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
            if event.get("inputs") != {"tag": args.tag, "commit": args.approved_commit}:
                raise RuntimeError("Publication differs from the dispatched tag/commit approval")
            if re.fullmatch(r"[0-9a-f]{40}", args.approved_commit) is None or args.source_root is None:
                raise RuntimeError("Explicit publication requires a full commit SHA and source checkout")
            # Run trusted workflow-revision tooling against the separately checked-out game revision.
            release.ROOT = args.source_root.resolve(strict=True)
        elif (args.source_root is not None or os.environ.get("GITHUB_EVENT_NAME") != "push"
              or os.environ.get("GITHUB_REF") != f"refs/tags/{args.tag}"):
            raise RuntimeError("Publication is allowed only for the triggering version-tag push")
        publish(args.repo, args.tag, args.input, expected_commit=args.approved_commit)
        return 0
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Release publication failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
