# ADR 0002: Validate content boundaries before schemas exist

- Status: Accepted
- Date: 2026-10-15
- Scope: Phase 0 content validation

## Context

The architecture separates reusable systems in game/ from specific definitions in
content/. No gameplay content types or schemas exist yet. Phase 0 must establish
executable validation without implementing items, weapons, enemies, or rooms.

## Decision

Provide a typed GDScript validator in tools/ and a standalone headless CLI entry.
Check that all six documented content directories exist, recursively inspect
files in sorted order, and permit only `.gitkeep` placeholders in Phase 0.
Reject every definition until its explicit schema validator is implemented.
Do not guess schemas, accept arbitrary unchecked resources, or load unvalidated
content scripts during this phase.

When a milestone introduces a content Resource type, extend this validator with
explicit dispatch to that schema and add valid/invalid fixtures. Validate IDs,
references, allowed effects and ranges as those contracts become defined. Keep
validation outside production gameplay systems. Preserve the game/content
dependency direction.

## Consequences

An empty content tree is valid and is reported as zero schemas/definitions.
Accidentally added content fails CI instead of passing a vacuous schema check.
Unit tests exercise missing directory and unregistered file failures. No claims
are made about validation of gameplay semantics before those schemas exist.
