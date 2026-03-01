# Core beliefs

These are the agent-first operating principles for building Swati.
They exist to reduce ambiguity and keep the codebase legible for future agents.

Last updated: 2026-02-24

## 1) Agent legibility is the goal

From an agent point of view, anything not in this repo does not exist.
If a decision matters:
- encode it in code, tests, or docs
- link it from docs/README.md and docs/design-docs/index.md

## 2) AGENTS.md is a map, not a manual

AGENTS.md should stay short.
It should point to:
- ARCHITECTURE.md (map)
- docs/ (system of record)
- the harness commands agents must run

## 3) Predictable structure beats cleverness

Agents navigate via filenames and directories.
We prefer:
- many small well-scoped files
- domain-named modules, not generic utils
- consistent context layout (facade, commands, queries, policies, adapters)

Reference: modular_monolith_design.md

## 4) Parse at boundaries, do not guess

Golden principle: do not build on guessed data shapes.

At boundaries:
- normalize input maps
- parse into the most precise representation available
- reject invalid data early with explicit error codes

In this repo, look for normalize functions in ingestion and policy modules.

## 5) Make feedback loops cheap

Agents work best when the loop is:
small change -> check -> fix -> repeat

Therefore:
- formatting is automatic and strict
- compile warnings are treated as errors (in harness)
- tests should be fast and deterministic

Run:
- mix swati.harness.check
- mix swati.docs.lint

## 6) Idempotency is not optional

Anything that can be retried will be retried.
Ingestion endpoints must be safe to call multiple times.
Use idempotency keys and test idempotency.

## 7) Invariants over prescriptions

We enforce boundaries and invariants centrally.
Inside those boundaries, agents have flexibility.

Examples of invariants:
- internal API response is versioned
- tool allowlists are explicit
- external calls have timeouts
- status transitions are centralized

## 8) When a rule repeats, upgrade it

If the same issue shows up repeatedly:
- write it down in this file as a golden principle
- then encode it as a harness check or structural test
- keep error messages remediation-oriented so an agent can fix it

## 9) The default workflow is a loop

The standard agent workflow is:
1) read AGENTS.md and ARCHITECTURE.md
2) read relevant docs in docs/
3) make a small change
4) run mix swati.harness.check
5) fix failures
6) update docs if behavior changed
7) repeat until green

When something fails, the fix is usually not "try harder".
The fix is to improve the scaffolding: docs, tests, scripts, lints.

## Escalation

Escalate to a human when judgment is required:
- product or UX decisions
- policy changes that increase risk (security, finance, PII)
- irreversible side effects
- when requirements are ambiguous