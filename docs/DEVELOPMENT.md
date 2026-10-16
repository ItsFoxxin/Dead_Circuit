# Dead Circuit development foundation

Phase 0 (`v0.0.0 — Development Foundation`) is complete.
`v0.0.1 — Combat Sandbox` is complete, manually accepted and merged to main;
see [COMBAT_SANDBOX.md](COMBAT_SANDBOX.md) for controls, implementation boundaries,
and the passed Windows artifact acceptance record. Its GitHub pre-release was
published manually and is preserved. v0.0.2 — Item / Synergy Proof is the next
gameplay milestone; this release-automation change includes no item gameplay. Multiplayer remains
unimplemented. The pinned foundation toolchain and CI gates are preserved.

## Requirements and setup

- Windows or Linux x86_64, Git, Python 3.12, and network access for first setup.
- Godot 4.7.2 stable, GUT 9.7.1, and gdtoolkit 4.5.0 are pinned.
- Allow disk space for the official multi-platform export-template archive
  (over 1 GB), extracted debug templates, editor, and dependency caches.

Run from the repository root on Windows PowerShell:

```powershell
py -3.12 -m venv .venv
.venv/Scripts/python.exe -m pip install -r tools/requirements-dev.txt
.venv/Scripts/python.exe tools/bootstrap.py --templates
.venv/Scripts/python.exe tools/dev.py validate
.venv/Scripts/python.exe tools/dev.py export --platform all
& .tools/godot/Godot_v4.7.2-stable_win64.exe --editor --path .
```

On Linux:

```sh
python3.12 -m venv .venv
.venv/bin/python -m pip install -r tools/requirements-dev.txt
.venv/bin/python tools/bootstrap.py --templates
.venv/bin/python tools/dev.py validate
.venv/bin/python tools/dev.py export --platform all
.tools/godot/Godot_v4.7.2-stable_linux.x86_64 --editor --path .
```

Omit `--templates` when only editing/testing. The bootstrap verifies SHA-256
checksums of both new and cached downloads before extracting. Dependencies stay
local and ignored; GUT's upstream MIT license is retained in addons/gut/.
Press Run Project in Godot to open the combat sandbox. No editor plugin
needs to be enabled to run command-line tests. The GUT plugin may optionally be
enabled locally for interactive test discovery.

## Commands

Use the venv Python executable in place of `python` below.

| Command | Purpose |
| --- | --- |
| `python tools/dev.py validate` | All checks and all GUT suites |
| `python tools/dev.py checks` | Import, format, lint, harness tests, content, headless launch |
| `python tools/dev.py tests` | Import, unit/integration/gameplay launch and determinism tests |
| `python tools/dev.py determinism` | Seeded fixture suite and two independent process probes |
| `python tools/dev.py content` | Import and content boundary validation |
| `python tools/dev.py smoke` | Import and main-scene startup/clean exit |
| `python tools/dev.py import` | Engine version check and headless editor import |
| `python tools/dev.py style` | gdformat check and gdlint |
| `python tools/dev.py metadata` | Generate local build provenance |
| `python tools/dev.py export --platform windows` | Windows debug export |
| `python tools/dev.py export --platform linux` | Linux debug export |
| `python -m gdtoolkit.formatter game tests tools` | Apply GDScript formatting |

The harness has bounded timeouts, rejects engine errors even with exit code zero,
requires explicit success markers for smoke/content checks, and rejects missing,
empty, failed, or skipped GUT JUnit reports. Logs, JUnit XML, deterministic probe
results, provenance, and step summaries are written under ignored reports/.
Run commands sequentially in a checkout; reports and generated provenance use
fixed paths. Each CI job has its own checkout.
Engine subprocess user data/config/cache is isolated under `.tools/user-data/`.

## Typed GDScript conventions

Use explicit types for fields, locals, loop variables, parameters, and returns.
Use typed collections when element types are known. Script preload constants may
use Godot's inferred script type (rather than erasing static calls to Script).
Use `Variant` only at external dynamic boundaries such as parsed JSON; narrow
with `is` before accessing values. Bare Dictionary is reserved for heterogeneous
JSON metadata. Prefer explicit scene references and ownership; introduce no
global player singleton or global gameplay state.

Use snake_case files/methods/fields, PascalCase named classes, UPPER_SNAKE_CASE
value constants, tabs, and gdformat's 100-column default. gdlint applies to
first-party game/, tests/, and tools/ GDScript; downloaded third-party source is
excluded. Godot treats untyped/inferred declarations and unsafe access/calls/casts
as errors. Keep any future suppression narrow, justified, and reviewed.
Commit Godot-generated `.gd.uid` files for first-party scripts; ignore .godot/.

## Structure and boundaries

The directories in ARCHITECTURE.md exist with placeholders until needed. The entry
scene injects the content sandbox into the bootstrap; reusable combat/session
mechanics remain in game/. Prototype weapon/enemy/wave definitions and the arena
remain in content/. Tools and test fixtures stay outside game/.
No roguelike run generation or item systems are implemented. Tests are organized into unit/,
integration/, determinism/, gameplay/, fixtures/, and Python harness/.

The content validator verifies directory availability, explicit weapon/enemy/wave
schemas, unique IDs, numeric bounds, and scene/spawn/navigation structure. Unknown
files remain errors. Add schema checks and invalid fixtures alongside future
content Resource types; see ADRs 0002 and 0003.

## Builds, versioning and CI

VERSION is canonical and must match application/config/version in project.godot.
The harness rejects mismatches. Exports contain generated JSON with commit SHA,
branch, engine version, version, CI/local build ID, build type, and dirty flag.
Generated provenance is ignored to avoid a new commit on every build. It is
packaged explicitly and copied beside each executable with SHA256SUMS.txt.
The launch surface can run directly from Godot without generated metadata; its
read-only accessor reports a local fallback in that case.

Development Windows and Linux x86_64 exports embed their pack and omit test and
development tooling, reports, and prior build outputs. The harness checks the
export manifest for these exclusions and required provenance. A matching-host
export runs a native headless launch smoke
before success; cross-exporting creates the binary but cannot prove it executes
on the other OS. CI exports on both native OSes and runs both smoke tests.
Windows exports are unsigned and use no signing credentials. Linux artifacts
downloaded as ZIP may require `chmod +x DeadCircuit.x86_64`.

ci.yml calls foundation.yml: validation -> native tests -> Foundation gate ->
optional native exports. Pull requests to dev/main run validation and tests.
Pushes to dev also upload both builds. Main runs the same gates and publishes
no release. A workflow_dispatch can request development artifacts for an inspected
branch. Reports and builds are retained for 14 days in GitHub Actions. Check the
actual run result before treating a build as validated. Pin updates through
Dependabot are targeted to dev; engine/GUT updates require a lockfile review.

The stable Foundation gate is suitable for a future required branch check.
Repository branch protection itself is an administrative follow-up; this workflow
does not modify main, merge PRs, deploy, or publish releases.

## Approved-tag releases

The dedicated release.yml publishes only version-tag pushes. Ordinary branch
pushes retain the existing CI behavior. VERSION and project.godot stay at 0.0.1
for this infrastructure task; the existing manual v0.0.1 pre-release is untouched.

For each future milestone:

1. Finish implementation on dev and pass automated CI.
2. Perform and record manual acceptance when required.
3. Merge the accepted milestone and release infrastructure to main.
4. Confirm VERSION and project.godot application/config/version agree.
5. Create an annotated tag on the accepted main commit and push it deliberately.
6. Wait for release.yml to validate, test, build, package and publish successfully.

Example for a future **accepted** v0.0.2, after its version files are updated:

```sh
git switch main
git pull --ff-only origin main
git tag -a v0.0.2 -m "Dead Circuit v0.0.2 — Item / Synergy Proof"
git push origin v0.0.2
```

Tags must be exactly vMAJOR.MINOR.PATCH, with no leading zeros, suffixes or build
metadata. The tag's commit must be reachable from fetched origin/main. Malformed
tags, version disagreement or unaccepted branch history fail before build work.
The workflow does not invent versions, create tags, or promote past releases.

All v0.x.y releases are GitHub pre-releases, permanently, and are never marked as
the latest stable release. v1.0.0 and higher default to stable releases with normal
GitHub latest selection. Titles are `Dead Circuit <tag>`. GitHub-generated release
notes are preserved with verified tag, commit, engine, platform and status details.

release-gates.yml reuses the unchanged foundation validation/test gates and fresh
native exports. Release builds use matching pinned release templates and Godot's
--export-release mode. Native startup smoke runs before packaging on each OS.
Development exports continue to default to debug mode and their existing paths.
Install release templates locally only when needed:

```sh
python tools/bootstrap.py --templates --release-templates
python tools/dev.py export --platform windows --build-type release --tag v0.0.1
```

The local release export requires a clean worktree and matching version. A cross
export is not a native smoke pass and cannot become a release ZIP. Native CI builds
provide that proof. All builds remain unsigned; no signing credentials are used.
Embedded metadata contains tag/version, SHA, engine, build type and build/run IDs.
The external per-platform metadata additionally records platform/native smoke.

The final GitHub Release has four assets:

- `DeadCircuit-<tag>-windows-x86_64.zip`
- `DeadCircuit-<tag>-linux-x86_64.zip`
- `SHA256SUMS.txt` covering both ZIPs and combined metadata
- `build-metadata.json` containing both native builds' provenance

Each ZIP contains its executable, per-platform metadata and internal checksums.
Linux ZIPs preserve execute permission. Both ZIPs must agree on commit, engine,
build and workflow-run identity; fresh packages come from the same workflow run.
Validation/build reports and unpublished packages also remain Actions artifacts
for 14 days. Release assets are separate from that Actions retention period.

Workflow permissions default to contents: read. Only the final publication job has
contents: write, using GitHub's GITHUB_TOKEN through GitHub CLI. No additional secret
is required. A draft is created only after all four assets verify, then uploaded
assets are checked before publication. A failed upload removes this run's draft
where possible. If cleanup or a network response is ambiguous, inspect the failed
run and named draft; tags are never removed. An existing release or draft causes
a clear failure without changing any asset. Re-running after a successful publish
therefore safely fails instead of overwriting history.

Use Actions **Dead Circuit CI → Run workflow → release-dry-run: true** on an
inspected branch to rehearse the full pipeline before merging release.yml. After
it is on main, **Publish approved version → Run workflow** is also a dry run.
Dry runs derive the label from VERSION and may bypass actual-tag/main-history
approval for feature-branch testing. They still run every gate and native build,
but cannot publish. Their current-version filenames are unpublished test assets;
use the commit SHA and release-plan.json to distinguish them from accepted releases.
Do not create a production tag merely to test this workflow.

Ensure Actions is enabled and repository/organization policy permits the publication
job's GITHUB_TOKEN contents: write and the pinned official actions. Tag protection
or rulesets restricting version-tag creation to maintainers are an optional
administrative safeguard; automation does not configure them. See
[ADR 0004](adr/0004-approved-tag-release-publishing.md).

Avoid storing active Git checkouts in synchronizing folders when possible.
OneDrive can rename `.git/HEAD` and `.git/config` into conflict copies, preventing
Git metadata collection. Preserve conflict files and repair from verified refs;
do not treat an unavailable commit SHA as a successful provenance check.

See [ADR 0001](adr/0001-phase-0-toolchain-and-gates.md) for toolchain decisions.
