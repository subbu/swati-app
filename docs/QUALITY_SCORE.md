# QUALITY_SCORE

This document makes quality visible and trackable for agents and humans.
It is not a blame tool. It is a prioritization tool.

Last updated: 2026-02-24

## How to read this

Each bounded context and cross-cutting layer gets a grade from 0 to 5.

0 - Unknown: no documented intent, little or no test coverage
1 - Fragile: works today, minimal tests, unclear boundaries
2 - Functional: basic tests, some docs, boundaries mostly respected
3 - Solid: good test coverage, clear boundaries, reliable ops story
4 - Excellent: strong invariants, fast feedback loops, good observability
5 - Reference: exemplary patterns others should copy

## Current grades

These are starting points. Update them as part of refactors.

| Area | Grade | Notes | Plan or debt link |
| --- | --- | --- | --- |
| Runtime Gateway (Swati.Runtime) | 3 | Contract versioned, clear flow, needs more structural tests | docs/exec-plans/tech-debt-tracker.md |
| Sessions ingestion | 3 | Idempotent inserts, case memory update | docs/exec-plans/tech-debt-tracker.md |
| Cases and memory | 2 | Good structure, memory rules need more docs and tests | docs/exec-plans/tech-debt-tracker.md |
| Channels (gmail, outlook, imap, whatsapp) | 2 | Adapters exist, needs more end-to-end tests | docs/exec-plans/tech-debt-tracker.md |
| Integrations and tools | 2 | Allowlist and serialization exist, needs security hardening | docs/exec-plans/tech-debt-tracker.md |
| Billing | 2 | Core exists, needs runbooks and reconciliation tests | docs/design-docs/razorpay_subscriptions_hld.md |
| Telephony | 2 | Provider adapter, needs reliability checklist | docs/exec-plans/tech-debt-tracker.md |
| Web UI (SwatiWeb) | 2 | LiveViews structured, needs UI regression harness | docs/exec-plans/tech-debt-tracker.md |
| Ops and deploy | 3 | Runbook exists, needs automation and drift detection | docs/references/production_system_setup.md |

## What moves the score

Raising a grade usually requires:
- Better tests (especially at boundaries)
- Clearer docs (design intent, invariants)
- Mechanical enforcement (lint or structural tests)
- Faster feedback loop (shorter time to detect a regression)

## Quality debt process

- Capture recurring issues in docs/exec-plans/tech-debt-tracker.md
- Convert recurring review feedback into golden principles and then into harness checks