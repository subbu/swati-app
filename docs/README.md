# Swati knowledge base

This docs/ tree is the system of record for humans and coding agents.
If knowledge is not in git (docs, code, tests), it effectively does not exist to agents.

If you are an agent: start with ../AGENTS.md.

## Progressive disclosure map

Top level:
- ../ARCHITECTURE.md - repo map and key flows
- DESIGN.md - coding and architecture norms
- PLANS.md - how to plan work
- QUALITY_SCORE.md - quality rubric and current gaps
- RELIABILITY.md - reliability rules and checklists
- SECURITY.md - security rules and secret handling

Directories:
- design-docs/ - architecture and design history (indexed)
- product-specs/ - what we are building (indexed)
- exec-plans/ - active and completed execution plans
- references/ - runbooks and reference material
- generated/ - generated artifacts (never hand-edit)

## Doc hygiene rules

- Keep docs short. Prefer links to deeper docs.
- Add a "Last verified: YYYY-MM-DD" line to operational runbooks.
- When code changes invalidate docs, update docs in the same PR.
- If a doc routinely goes stale, encode the rule as a harness check (see mix swati.docs.lint).

## Mechanical checks

- mix swati.docs.lint - validates the required docs layout and indexes
- mix swati.harness.check - runs fast quality checks (format, compile, tests)