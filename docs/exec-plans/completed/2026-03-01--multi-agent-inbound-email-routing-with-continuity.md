# Multi-Agent Inbound Email Routing with Continuity + Inbox UI

Status: active
Created: 2026-03-01
Owner: Subbu (@athikunte) + Codex
Link: TBD

## Goal

Enable provider-agnostic inbound email intake (starting with Resend) where:
- no provider-specific hardcoded public routes per integration
- one deterministic owner agent per thread
- continuity preserved across replies/retries/provider callbacks
- tenant users can view all email, linked cases, routing reasons, and delivery health

## Non-goals

- Build every provider adapter in first pass (focus: Resend-first adapter contract)
- Replace existing Gmail/Outlook/IMAP sync flows immediately
- Implement autonomous multi-agent fan-out replies on same thread
- Redesign case model outside email/thread ownership requirements

## Context

Current state:
- Public API has hardcoded webhook endpoints for billing + WhatsApp only.
- Email channel behavior today is sync-based (Gmail/Outlook/IMAP polling).
- Inbound event ingestion already exists via internal endpoint and runtime resolution.

Observed issue:
- Resend webhook configured to `/api/v1/email_received` fails with `404 Not Found`.

Product ask from discussion:
- Do not hardcode one-off email webhook paths.
- Extend agent system so agents own routing decisions.
- Preserve thread continuity in multi-agent tenants.
- Add UI for tenant visibility: all email, linked cases, ownership, why-routed, failures.

## Constraints

- Reuse existing ingestion/runtime contracts where possible; avoid parallel pipelines.
- Keep webhook processing fast: verify + enqueue + ack.
- Deterministic routing; no ambiguous owner on same thread.
- Idempotent against provider retries.
- Full auditability for trust/replay/debugging.
- Backward compatible with current channel stack during rollout.

## Approach

### 1) Inbound connector control plane (tenant-level)

Add `inbound_connectors`:
- `id`, `tenant_id`, `provider`, `status`
- `endpoint_token` (public path token)
- `signing_secret_id` (secret store reference)
- `default_channel_key`, `default_endpoint_address`
- `default_agent_id`, `routing_mode`
- `inserted_at`, `updated_at`

Purpose:
- isolate provider config from code routes
- allow many connectors per tenant
- support future providers with same contract

### 2) Generic inbound endpoint

Add one public endpoint:
- `POST /api/v1/inbound/:connector_token`

Flow:
1. Resolve connector by token.
2. Verify provider signature + freshness window.
3. Normalize payload to canonical email envelope.
4. Insert `inbound_deliveries` row (idempotency key).
5. Enqueue async processing job.
6. Return 2xx fast.

No provider-specific route additions after this (adapter/plugin only).

### 3) Canonical inbound email envelope

Normalize each provider payload into stable shape:
- `provider`, `provider_event_id`, `received_at`
- `from`, `to[]`, `cc[]`, `bcc[]`
- `subject`, `text_body`, `html_body`
- `attachments[]` (metadata + stored refs)
- `message_id`, `in_reply_to`, `references[]`, `provider_thread_id`
- `headers`, `raw_payload_ref`

### 4) Continuity-first routing algorithm

Routing order:
1. **Continuity match** (highest): existing open session/case/thread with owner agent.
2. **Address binding**: exact `to_address -> owner_agent_id`.
3. **Agent inbound rules**: evaluate all enabled rules, deterministic winner.
4. **Tenant default fallback** agent/queue.
5. **Dead-letter** if no safe route.

Continuity key strategy:
- prefer `provider_thread_id`
- else `message_id`/`in_reply_to`/`references` linkage
- else fallback hash: normalized subject + participants + endpoint

Ownership invariants:
- one owner agent per thread at a time
- optional watcher agents allowed, no auto-reply rights
- ownership changes only via explicit handoff policy/action

### 5) Agent inbound rules model

Add `agent_inbound_rules`:
- `agent_id`, `tenant_id`, `enabled`, `priority`
- predicates: connector/provider, recipient/address/domain, subject/header match, channel type
- action: `owner|watcher|silent`, optional case metadata defaults
- deterministic tie-break metadata

Rule behavior:
- evaluate all matches
- sort by priority + specificity + stable tie-break
- choose single owner action winner

### 6) Reuse existing ingestion runtime

Adapter processing must emit payload compatible with channel ingestion:
- map envelope -> internal `channel.message.received` event
- call existing ingestion entrypoint
- preserve session/case/customer/runtime linking behavior

### 7) Tenant UI surfaces

#### Inbox (new)
- tenant-wide email list (inbound + outbound)
- filters: agent, case, address, connector, status, time
- search: subject/from/to/thread/case
- per row: owner agent, linked case, continuity status

#### Thread detail (new)
- message timeline
- continuity panel (match method + confidence)
- ownership panel (current owner + history + handoff)
- "Why routed here" panel (binding/rule/fallback explanation)
- linked case panel + quick actions

#### Channels > Email (extend)
- connector list, health, last event, failure rate
- address bindings UI (`address -> owner agent`)
- adapter test payload + route preview

#### Agents > Inbound Rules (extend)
- rule builder + precedence UI
- overlap/conflict warnings
- dry-run evaluator with sample envelope

#### Trust > Inbound Deliveries (new/extend)
- webhook delivery log, signature result, idempotency result
- dead-letter queue + replay controls
- drill-down to raw payload + normalized envelope + error reason

### 8) Observability + audit

Store auditable rows for:
- delivery receipt + verification outcome
- dedupe decision
- continuity decision path
- routing winner + loser candidates
- ownership changes/handoffs
- replay attempts/results

## Milestones

- [x] M1: Domain model + migrations (`inbound_connectors`, `inbound_deliveries`, `agent_inbound_rules`; `thread_ownership_events` deferred)
- [x] M2: Generic inbound endpoint + adapter contract + Resend adapter + signature verification
- [x] M3: Canonical envelope + async job + idempotency + ingestion bridge
- [x] M4: Continuity resolver + routing precedence engine + deterministic tie-breaks
- [x] M5: Owner/watcher permissions + reply lock invariants + handoff policy hooks (`inbound_thread_ownership_events` + `inbound.ownership.changed` audit events + accepted-handoff owner transfer hook via `target_agent_id`)
- [x] M6: Inbox + thread detail UI (routing reason + continuity panels) (`/inbound-email/inbox` message-level view + linked case/session navigation + `/sessions/:id` ownership history panel)
- [x] M7: Channels/Agents/Trust UI extensions (bindings, rules, deliveries, replay) (`/inbound-email` bindings/rules/preview/replay + `/trust/inbound` delivery health + replay + payload drilldown)
- [ ] M8: Rollout guards, telemetry dashboards, docs, and deprecation plan for ad-hoc inbound paths - partial (feature flag + inbound telemetry metrics added; dashboards + migration/deprecation runbook still pending)

## Test plan

Core correctness:
- connector token resolution and tenant isolation
- signature verification pass/fail/timestamp skew
- idempotency under webhook retries and duplicate provider event IDs
- canonical envelope mapping coverage (Resend payload variants)

Routing + continuity:
- same thread routes to same owner across multiple messages
- continuity miss falls back to bindings/rules/default in order
- multiple matching rules resolve deterministically
- disabled/deleted owner triggers configured handoff behavior

Failure/recovery:
- malformed payload -> delivery failure row, no crash
- ingestion errors -> retry/backoff + dead-letter after threshold
- replay from dead-letter succeeds and links to prior attempt

UI:
- inbox filters/search correctness
- thread detail shows routing reason + continuity info
- permissions enforce read/manage boundaries

Regression:
- existing Gmail/Outlook/IMAP sync flows still ingest/send
- existing WhatsApp and billing webhooks unaffected

## Rollout and rollback

Rollout:
1. Ship schema + behind feature flag (`inbound_connectors_v1`).
2. Enable generic inbound endpoint for internal test tenant.
3. Turn on Resend connector for selected tenant(s).
4. Enable UI in read-only mode first (delivery visibility).
5. Enable routing rules + ownership actions.
6. Gradually migrate tenants from ad-hoc inbound paths.

Rollback:
- disable feature flag to stop connector processing
- keep endpoint returning accepted + no-op (or controlled reject) per safety choice
- preserve stored deliveries/events for replay after re-enable

## Observability

Logs, metrics, traces, dashboards, alerts:
- inbound requests/sec by connector/provider
- signature failure rate
- dedupe hit rate
- continuity hit rate
- routing fallback rate
- dead-letter count + replay success rate
- owner handoff count per tenant

## Risks

- Thread-link false positives/negatives -> continuity mistakes
- Rule overlap complexity -> operator confusion without clear explainability
- Attachment handling/storage growth
- Potential trust gap if routing reason not visible in UI
- Migration complexity across existing email sync model

## Progress log

- 2026-03-01 - Plan created from product discussion (multi-agent + continuity + UI scope)
- 2026-03-01 - Implemented schema: `inbound_connectors`, `inbound_deliveries`, `agent_inbound_rules`.
- 2026-03-01 - Implemented generic inbound endpoint: `POST /api/v1/inbound/:connector_token`.
- 2026-03-01 - Implemented Resend signature verification + payload normalization + processing worker.
- 2026-03-01 - Implemented continuity-first route resolver with endpoint defaults, rules, and fallback.
- 2026-03-01 - Added tenant UI at `/inbound-email` for connectors, rules, deliveries, and email thread visibility.
- 2026-03-01 - Added regression tests for webhook ingest, idempotency, signatures, and continuity routing.
- 2026-03-01 - Fixed connector secret FK regression (`returning: true` + FK constraint handling) and validated with live connector.
- 2026-03-01 - Fixed session transcript rendering gap for inbound email (`channel.message.received/sent` now rendered as messages with subject fallback).
- 2026-03-01 - Added session-level inbound route summary panel (`reason`, `continuity`, `thread`, `from/to/subject`) for email sessions.
- 2026-03-01 - Added deterministic rule tie-break (`priority + specificity + stable order`) and watcher capture in routing.
- 2026-03-01 - Added address bindings management, route preview, and delivery replay controls in `/inbound-email`.
- 2026-03-01 - Added inbound routing audit write-back (`session.metadata.inbound_routing` + `inbound.routing.resolved` session event).
- 2026-03-01 - Added inbound rollout/observability primitives: `inbound_connectors_v1` feature flag gate + telemetry events/metrics for ingest/process/replay.
- 2026-03-01 - Validated external E2E send from `~/Projects/sgp` to `support@swati.ai` through Resend webhook to routed session.
- 2026-03-01 - Added ownership continuity primitives: `inbound_thread_ownership_events` table, `Swati.Inbound.Ownership`, and `inbound.ownership.changed` session event emission.
- 2026-03-01 - Added handoff owner-transfer hook: accepted handoff can move thread owner via `target_agent_id` metadata and append ownership audit.
- 2026-03-01 - Added tenant message inbox UI at `/inbound-email/inbox` with filters and direct links to sessions/cases.
- 2026-03-01 - Added Trust inbound UI at `/trust/inbound` with delivery filters, signature visibility, replay action, and payload/route drilldown.
- 2026-03-01 - Validated `~/Projects/sgp` initiated full ingestion by signed webhook simulation against ngrok connector URL; verified delivery/session/case/ownership/session-event linkage.
- 2026-03-01 - Tested realistic inbound rule/preview scenarios (mixed-case + display-name email headers) and fixed matching gaps via normalized address parsing + tenant-scoped endpoint lookup in routing.
- 2026-03-01 - Added tenant/provider-aware SMTP transport policy resolver (`strict|compatible|insecure`) with connector metadata override + provider profile defaults; configured Resend SMTP profile to fall back on `max_path_length_reached`.
- 2026-03-01 - Normalized outbound agent email event payloads (`from/to/subject/text/direction/provider_response`) so sent emails render in `/inbound-email/inbox` and session transcript consistently.
- 2026-03-01 - Added IMAP-only UI control (`Email delivery mode`) in Channels and Surfaces connect sheets; persists per-connection metadata override while keeping Gmail/Outlook OAuth paths unchanged.

## Decision log

- 2026-03-01 - Chosen: generic connector endpoint + adapter model; no provider-specific route hardcoding.
- 2026-03-01 - Chosen: continuity-first routing, then bindings, then rules, then fallback.
- 2026-03-01 - Chosen: single owner agent per thread; optional watchers; explicit handoff for ownership changes.
- 2026-03-01 - Chosen: tenant-facing Inbox/Thread/Trust UI with "why routed" explainability.
