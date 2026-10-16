# ADR 0007: Explicit accepted-main release action

- Status: Accepted
- Date: 2026-10-16
- Scope: Release tooling; no gameplay or version change
- Extends: ADR 0004

## Decision

The owner requested a downloadable release with update notes whenever an accepted
milestone is promoted to main. Retain release.yml's approved-tag push path and its
always-unpublished workflow_dispatch rehearsal. Add a separate publish-main.yml
manual action requiring an explicit semantic tag and full accepted commit SHA.
It runs only from main, verifies both version files at that immutable revision
and its reachability from origin/main, then creates an annotated tag. Existing
releases are rejected without changes; an existing matching tag can resume failed
gates, while a moved tag fails. Never delete or replace version tags.

The final publisher explicitly authorizes this named workflow_dispatch on main,
checks its original tag/commit inputs, and requires the source checkout to equal
the approved full SHA. The original tag-push authorization and unpublished dry-run
path remain unchanged. Publication uses tooling from the workflow revision in a
separate checkout: accepted historical game commits must not execute an older
publisher that lacks the manual path. Versions, ancestry, tag identity, toolchain
and asset provenance are still validated against the accepted game checkout.

This provides a supported GitHub UI path without local Git credentials or a new
secret. The GitHub connector currently cannot create tags. Tags written with
GITHUB_TOKEN do not recursively trigger push workflows, so the manual action
directly reuses release-gates.yml and the existing draft-first publisher.

Reusable workflows gain an optional source-ref checkout input, defaulting to the
original triggering SHA. All validation, native tests, native Windows/Linux release
exports, smoke checks, provenance and archive checks run against the explicitly
approved commit. Workflow-run artifact keys still identify the current run; build
metadata records the actual checked-out source SHA. Only tag preparation and final
publication jobs have contents: write. Other jobs remain read-only. Tag and manual
publication paths serialize on the same version tag.

Main merges alone still do not publish automatically. The deliberate manual action
records approval and then performs the complete release pipeline. The owner has
authorized releasing accepted main milestones; future agents should include this
step when promoting such a milestone. Dev integration alone is not acceptance for
main or a release; v0.0.3's separate owner approval is recorded in SEEDED_RUNS.md.
Major-zero versions remain pre-releases; historical v0.0.1 is
preserved. Failed gates leave the tag for inspection and publish no release.

## Verification

Harness tests cover annotation/ref creation, malformed/mismatched approval, main
ancestry, existing-release preservation, matching-tag retry, moved-tag rejection,
minimal permissions and source checkout through every reused gate. Regression
coverage verifies the explicit manual publisher authorization and separate trusted
tooling checkout. The first live attempt passed both native builds but exposed the
old publisher's tag-push-only guard; it published no release. The corrected path
reuses the matching v0.0.2 tag without moving it or releasing v0.0.3 dev gameplay.

## Reference

- https://docs.github.com/en/actions/concepts/security/github_token
