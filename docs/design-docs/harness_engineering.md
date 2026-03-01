# Harness engineering for Swati

This doc describes the agent-first harness scaffolding in this repository.
Goal: let agents reliably produce high-quality changes with minimal human attention.

Last updated: 2026-02-24

## What we are optimizing for

- Fast feedback loops (cheap checks, easy reproduction)
- Predictable structure (agents can navigate)
- Repository-local knowledge (docs are the system of record)
- Mechanical enforcement (linters and harness tasks catch drift)
- Progressive disclosure (map first, details later)

## Knowledge base layout

- AGENTS.md (repo root): table of contents for agents
- ARCHITECTURE.md (repo root): map of code and flows
- docs/README.md: knowledge base entry
- docs/design-docs/: architecture and design history (indexed)
- docs/product-specs/: product requirements (indexed)
- docs/exec-plans/: active and completed execution plans
- docs/references/: runbooks and reference material
- docs/generated/: generated artifacts

Docs layout is validated by:
- mix swati.docs.lint

## Execution plans

Complex work should be captured as execution plans:
- docs/exec-plans/active/
- docs/exec-plans/completed/

See docs/PLANS.md and docs/exec-plans/template.md.

## Harness commands

The minimum local loop:
- mix swati.harness.check
- mix swati.docs.lint

Convenience scripts:
- scripts/harness/check.sh
- scripts/harness/docs-lint.sh
- scripts/harness/new-exec-plan.sh

## Golden principles

Golden principles live in docs/design-docs/core-beliefs.md.
When a principle repeats in review:
- promote it into a harness check or structural test

## Next steps

Recommended follow-ups once this scaffold is in place:
1) Add structural tests for key boundaries (web layer stays thin, context dependencies)
2) Add a scheduled doc gardening job that opens PRs for stale docs
3) Add a quality bot that updates QUALITY_SCORE.md based on test coverage and lint results
4) Add worktree scripts for fast ephemeral environments (ports and DB isolation)