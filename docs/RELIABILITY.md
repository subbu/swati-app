# RELIABILITY

Reliability is a product feature.
This document captures the invariants and checklists we want agents to follow.

Last updated: 2026-02-24

## Core invariants

### Internal runtime APIs

- All internal endpoints live under /internal/v1/.
- Auth is Bearer token in the authorization header.
- Timestamps are RFC3339 UTC with microsecond precision.
- Runtime config responses are versioned. Bump Swati.RuntimeConfig.version/0 when shape changes.

Source of truth: design-docs/internal_runtime_config.md

### Ingestion is idempotent

Event ingestion endpoints must be safe to retry.
We rely on idempotency keys for:
- sessions events
- calls events (data plane, if applicable)
- webhooks that trigger side effects

### Explicit status transitions

If a record has a status machine, keep transitions in a dedicated module.
Examples in this repo:
- Swati.Calls.CallStatusTransitions
- Swati.Sessions and session status updates

### Timeouts and external calls

External calls must have explicit timeouts and clear error surfaces.
Prefer:
- Req clients behind behaviours
- centralized retry policy
- structured logs with correlation ids

## Checklists

### When changing runtime resolution

- Update design-docs/internal_runtime_config.md if request or response changes.
- Bump runtime config version if response shape changes.
- Add tests for both success and failure cases.
- Verify failure codes remain canonical and stable.

### When changing event ingestion

- Ensure insert is idempotent.
- Ensure events are normalized in a single place.
- If memory or derived state changes, add a regression test.

### When changing background jobs (Oban)

- Ensure jobs are safe to retry.
- Ensure queues and cron schedules are documented.
- Add a runbook note if ops needs to know.

Ops runbook: references/production_system_setup.md