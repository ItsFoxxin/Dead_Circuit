# ADR 0010: Bounded content production

- Status: Accepted
- Date: 2026-10-17
- Scope: Content growth through v0.1.0

## Context

Dead Circuit must expand its item and other concrete content pools without making
core systems depend on specific content or allowing many small tasks to invent
incompatible mechanics. Codex and FoxForge need a stable responsibility boundary,
a reviewable branch flow and an explicit response when a proposed item cannot be
expressed with the existing reusable language.

Accepted ADRs already define composition, attribution, seeded authority, run
lifetime and release gates. This decision preserves those contracts and defines
how future content work uses them.

## Decision

Codex owns architecture, reusable systems and primitives, schemas, core events,
run-state authority, ownership rules, major migrations, cross-system integration
and difficult regressions. FoxForge may independently produce small concrete
content changes only when existing modifiers, triggers, conditions, effects, tags
and state contracts fully express them.

When content requires a new reusable mechanic, FoxForge stops and reports
`NEW PRIMITIVE REQUIRED` with the desired behavior, missing capability, reason the
existing primitives are insufficient and suggested tests. Codex implements and
validates the shared primitive before content work resumes. One-off item scripts,
item-pair branches and silent schema expansion are rejected.

Both roles branch from current `origin/dev`, use their documented namespace and
target `dev` through focused pull requests. FoxForge uses one item or a very small
coherent group per short-lived branch. Every change remains subject to AGENTS.md,
content validation, targeted tests and the complete CI regression gates.

The detailed task template, item-growth guidance and milestone workflow live in
CONTENT_WORKFLOW.md so operational guidance can evolve without changing this
architectural responsibility boundary.

## Consequences

Concrete content can scale in parallel while dependency direction, source
ownership, deterministic authority and per-player state stay consistent. A new
mechanic may temporarily block an individual content task, but it receives one
reviewed reusable implementation instead of multiple content-specific versions.

The roadmap's item counts remain planning targets rather than release gates.
Reviewers may defer filler, unsafe content or large mixed pull requests even when
that means missing a numerical target. This ADR introduces no gameplay and does
not authorize work beyond the active accepted milestone boundary.
