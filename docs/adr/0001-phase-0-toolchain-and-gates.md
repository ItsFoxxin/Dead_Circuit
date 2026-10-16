# ADR 0001: Phase 0 toolchain and validation gates

- Status: Accepted
- Date: 2026-10-15
- Scope: v0.0.0 development foundation

## Context

The architecture requires Godot 4.7.x stable, typed GDScript, automated validation,
and Windows/Linux development artifacts. It does not select test or lint tooling.
The dev branch initially contained only the original README; the existing main
design documents are brought forward unchanged before implementing the foundation.

## Decision

Pin Godot 4.7.2 stable and its matching standard (non-.NET) export templates.
Use GUT 9.7.1, the upstream Godot 4.7-compatible test framework, and gdtoolkit
4.5.0 for gdformat/gdlint. Use Python 3.12 for small orchestration scripts and
pytest for testing failure detection in that orchestration. Python is development
tooling only; production code remains typed GDScript.

Store engine/GUT immutable references and archive SHA-256 digests in
`tools/toolchain.json`, with pinned Python dependencies in
`tools/requirements-dev.txt`. Install downloads under ignored `.tools/` and GUT
under ignored `addons/gut/`; include its upstream license during extraction.
Verify archive digests on every bootstrap, including cache hits. Network access
is required on first setup. Cache archives in CI, not imported project state.

Use the Compatibility renderer for the minimal launch screen and broadly usable
development builds. This makes no decision about the eventual 3D rendering path.

Use one reusable workflow with sequential validation, native Windows/Linux test
jobs, a stable aggregate foundation gate, then optional native development exports.
PRs to dev/main run the gates. Pushes to dev additionally export both platforms.
Main uses the same gates without automatically publishing a release. Repository
administrators can later require the aggregate gate using branch protection.
CI does not change branch protection, deploy, sign, or publish releases.

Build debug exports with embedded packs, exclude tests/tooling/docs/addons, and
include generated JSON provenance inside the pack and beside the executable.
Each build contains a version, full commit SHA, branch, exact engine version,
development build ID, and dirty-worktree flag. VERSION is authoritative; reject
project settings that disagree. CI build IDs derive from run number and attempt;
local IDs use `local.1`. Do not embed wall-clock timestamps.

## Consequences

Engine/GUT upgrades are deliberate lockfile changes followed by full validation.
The GUT dependency is not shipped in development exports. The small Python harness
only composes established tools, checks reports/logs, and preserves diagnostics.
Development artifacts are unsigned, expire after 14 days in Actions, and require
native execution smoke tests before upload. Artifact ZIPs may lose Linux execute
permissions; restore with `chmod +x DeadCircuit.x86_64` after downloading.

No networking, player state, gameplay RNG, combat systems, or content definitions
are introduced. Determinism tests use test-only RNG fixtures; they establish the
test path rather than claiming future run determinism or cross-version RNG stability.

## References

- https://godotengine.org/download/archive/4.7.2-stable/
- https://github.com/bitwes/Gut/tree/v9.7.1
- https://github.com/Scony/godot-gdscript-toolkit/tree/4.5.0
