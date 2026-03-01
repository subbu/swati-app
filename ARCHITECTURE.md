# ARCHITECTURE

This is the map of the Swati control-plane repository for humans and coding agents.
Keep this file short and stable. Add details in docs/ and link back here.

Last updated: 2026-02-24

## What this repo is

Swati is an agent platform with:
- Control plane (this repo): Phoenix app for configuration, UI, and internal APIs used by runtimes.
- Data plane runtimes (voice, etc): call the control plane internal API to resolve runtime config, then ingest events.

## How to navigate

Start from:
- AGENTS.md (how agents should work in this repo)
- docs/README.md (knowledge base index)
- docs/DESIGN.md (coding and architecture rules)
- docs/design-docs/index.md (design docs catalog)

## Key flows

### Runtime resolution (control-plane to data-plane contract)

Entry: SwatiWeb.Internal.RuntimeController.resolve
- POST /internal/v1/runtime/resolve
- delegates to Swati.Runtime.resolve_runtime/1

Swati.Runtime.resolve_runtime/1 performs:
1) Resolve endpoint and channel (by id or by channel_key/channel_type and address)
2) Resolve or upsert customer identity
3) Resolve or create case (case linking)
4) Pick agent (endpoint routing default, case assignment, fallback)
5) Authorize agent to channel and endpoint scope
6) Resolve or create session
7) Resolve tool sources (channel tools, integrations, webhooks)
8) Compute effective tool policy and tool definitions
9) Build agent system prompt Markdown

Design doc: docs/design-docs/internal_runtime_config.md

### Session ingestion and case memory

Entry: SwatiWeb.Internal.SessionsController
- POST /internal/v1/sessions/:session_id/events
- delegates to Swati.Sessions.Ingestion.append_events/2

Swati.Sessions.Ingestion.append_events/2:
- normalizes events
- inserts SessionEvent rows idempotently (session_id + idempotency_key)
- touches session.last_event_at and transitions open to active
- updates associated case memory from events

## Bounded contexts

Primary contexts live under lib/swati and are exposed via small facade modules:
- Identity: Accounts, Tenancy
- Agent Studio: Agents
- Runtime Gateway: Runtime, RuntimeConfig
- Sessions: Sessions
- Cases: Cases
- Channels: Channels
- Tool Integrations: Integrations, Webhooks, Tools
- Billing: Billing
- Telephony: Telephony
- Observability and policy: Policies, Audit

See: docs/design-docs/modular_monolith_design.md

## Architectural rules

- Facades stay small and stable (Swati.ContextName). Put logic in Commands, Queries, Policy modules, and Adapters.
- Controllers and LiveViews call facades or application services, not domain internals.
- Prefer small, well-scoped modules. If a module grows, split it.

## Cross-plane and security invariants

- Internal API auth: authorization header must be "Bearer SWATI_INTERNAL_API_TOKEN".
- Runtime config is versioned. Bump Swati.RuntimeConfig.version/0 when response shape changes.
- Timestamps are UTC with microsecond precision (see Swati.DbSchema).

## Where to add things

- New business capability: add or extend a bounded context under lib/swati.
- New external integration: add a Port behaviour and an Adapter (Req-based), then wire via the context facade.
- New internal API endpoint: add controller under lib/swati_web/controllers/internal and keep it thin.