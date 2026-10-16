"""Explicitly approve an accepted main commit and create its annotated release tag."""

import argparse
import json
import os
import re
import subprocess
import sys

import publish_release
import release


def prepare(repo: str, tag: str, expected_commit: str) -> dict:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise RuntimeError("Expected owner/repository")
    if not re.fullmatch(r"[0-9a-f]{40}", expected_commit):
        raise RuntimeError("Approval requires the full accepted commit SHA")
    version, _ = release.tag_version(tag)
    # Inspect the approved revision without executing its scripts or modifying files.
    if release.git("rev-parse", f"{expected_commit}^{{commit}}") != expected_commit:
        raise RuntimeError("Approved commit could not be resolved exactly")
    if subprocess.run(["git", "merge-base", "--is-ancestor", expected_commit, "origin/main"],
                      cwd=release.ROOT, check=False).returncode:
        raise RuntimeError("Approved commit is not reachable from origin/main")
    if release.git("show", f"{expected_commit}:VERSION") != version:
        raise RuntimeError("Approved tag does not match VERSION")
    project = release.git("show", f"{expected_commit}:project.godot")
    application = re.findall(r"(?ms)^\[application\]\s*\n(.*?)(?=^\[|\Z)", project)
    versions = re.findall(r'^config/version="([^"]+)"\s*$', application[0], re.MULTILINE) if len(application) == 1 else []
    if versions != [version]:
        raise RuntimeError("Approved tag does not match project.godot")
    if publish_release.api(repo, f"releases/tags/{tag}", missing_ok=True) is not None:
        raise RuntimeError("Release already exists; refusing to change it")
    existing = publish_release.api(repo, f"git/ref/tags/{tag}", missing_ok=True)
    if existing is None:
        annotated = publish_release.api(repo, "git/tags", method="POST", payload={
            "tag": tag, "message": f"Dead Circuit {tag} - accepted main milestone",
            "object": expected_commit, "type": "commit"})
        publish_release.api(repo, "git/refs", method="POST", payload={
            "ref": "refs/tags/" + tag, "sha": annotated["sha"]})
    publish_release.verify_remote_tag(repo, tag, expected_commit)
    return {"tag": tag, "commit": expected_commit, "version": version,
            "existing_matching_tag": existing is not None}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    try:
        plan = prepare(os.environ.get("GITHUB_REPOSITORY", ""), args.tag, args.commit)
        reports = release.ROOT / "reports"
        reports.mkdir(exist_ok=True)
        (reports / "tag-approval.json").write_text(json.dumps(plan, indent=2) + "\n")
        if destination := os.environ.get("GITHUB_OUTPUT"):
            with open(destination, "a", encoding="utf-8") as output:
                output.write(f"tag={plan['tag']}\ncommit={plan['commit']}\n")
        print(json.dumps(plan))
        return 0
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
