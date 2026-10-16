# Dead Circuit development foundation

Phase 0 (`v0.0.0 — Development Foundation`) is complete and preserved on main.
The dev milestone `v0.0.1 — Combat Sandbox` is complete and manually accepted;
see [COMBAT_SANDBOX.md](COMBAT_SANDBOX.md) for controls, implementation boundaries,
and the passed Windows artifact acceptance record. v0.0.2 — Item / Synergy Proof
is the next active milestone; implementation has not begun. Multiplayer remains
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

Avoid storing active Git checkouts in synchronizing folders when possible.
OneDrive can rename `.git/HEAD` and `.git/config` into conflict copies, preventing
Git metadata collection. Preserve conflict files and repair from verified refs;
do not treat an unavailable commit SHA as a successful provenance check.

See [ADR 0001](adr/0001-phase-0-toolchain-and-gates.md) for toolchain decisions.
