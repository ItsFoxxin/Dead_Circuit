# ADR 0004: Approved tags, native release gates and staged publication

- Status: Accepted
- Date: 2026-10-16
- Scope: Release automation; no gameplay or version increment

## Decision

An explicitly pushed `vMAJOR.MINOR.PATCH` tag approves a release. Accept only three
nonnegative decimal components without leading zeros (except zero itself), suffixes
or build metadata. The tag must resolve to the checked-out commit, that commit must
be reachable from fetched origin/main, and VERSION and application/config/version
must match. Human acceptance precedes tagging; automation cannot infer gameplay
acceptance from a branch name or test result.

Major-zero versions are permanent historical GitHub pre-releases and never become
the latest stable release. Major one and above default to stable releases with
GitHub's normal automatic latest behavior. Do not infer milestone titles from
commit messages. Preserve GitHub-generated notes and prepend verified provenance.

release.yml calls read-only release-gates.yml, which reuses foundation.yml's full
validation, native Windows/Linux tests and aggregate gate. Fresh native exports use
matching pinned release templates and --export-release; development export defaults
remain unchanged. Every release package requires a native executable smoke pass,
clean provenance, matching version/tag/SHA/engine/build/run IDs and valid checksums.
Only packages from the current workflow run are assembled; no old dev artifacts
are reused. ZIPs preserve Linux executable permissions.

Only the final publication job receives contents: write through GITHUB_TOKEN.
GitHub CLI stages a new draft after all local assets exist and verify, uploads and
checks every asset, checks the remote tag again, then publishes. Upload failures
remove only this run's still-draft release where possible. Tags are never deleted.
Ambiguous network/cleanup failures fail the job and identify the draft for inspection;
a successfully published release is never deleted by cleanup.

If any release (including a draft) already exists for the tag, fail without changing
it or its assets. Same-ref runs are serialized. This deliberately protects the
manually published v0.0.1 pre-release and avoids silent replacement on re-runs.

workflow_dispatch is always an unpublished dry run. ci.yml offers a read-only
release-dry-run dispatch bridge so feature/dev branches can exercise the reusable
gates before release.yml is merged to the default branch. Dry runs may verify a
branch without an actual tag or main ancestry; publication has no such exception.
They still require matching versions, clean exports, every foundation gate and both
native smoke passes. They create Actions artifacts, never tags or GitHub Releases.

## Consequences

Release infrastructure must be merged to main before tagging a future milestone.
The v0.0.1 manual release is neither rebuilt nor replaced by this change. No tag or
release is created to test publishing. Publication rollback and duplicate behavior
are tested with mocked GitHub responses; live publication awaits a deliberate
accepted-milestone tag. No extra secret, gameplay abstraction, networking, signing
credential or release dependency is added. GitHub CLI is provided by the hosted
Ubuntu runner; Python packaging uses the standard library.

## References

- https://docs.github.com/en/rest/releases/releases
- https://cli.github.com/manual/gh_release_upload
- https://docs.github.com/en/actions/using-workflows/reusing-workflows
