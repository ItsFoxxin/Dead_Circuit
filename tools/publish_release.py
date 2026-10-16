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


def publish(repo: str, tag: str, directory: Path) -> None:
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo) is None:
        raise RuntimeError("Expected owner/repository")
    plan = release.validate(tag)
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
    args = parser.parse_args()
    try:
        if os.environ.get("GITHUB_EVENT_NAME") != "push" or os.environ.get("GITHUB_REF") != f"refs/tags/{args.tag}":
            raise RuntimeError("Publication is allowed only for the triggering version-tag push")
        publish(args.repo, args.tag, args.input)
        return 0
    except (RuntimeError, OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"Release publication failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
