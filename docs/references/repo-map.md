# Repo map

This is the navigation map for the Swati control-plane repository.
Keep it short. Prefer links to deeper docs.

Last updated: 2026-03-01

## Top level

- AGENTS.md - agent entrypoint (keep short)
- ARCHITECTURE.md - architecture map
- docs/ - knowledge base
- lib/ - application code
- priv/repo/migrations - DB schema history
- rel/ - release scripts
- scripts/ - one-off scripts
- test/ - test suite

## lib/swati

Bounded contexts (non-exhaustive):
- agents/ - agent configs, versions, tool policies, compilation
- runtime/ - runtime resolution and system prompt
- sessions/ - session model, ingestion, timeline
- calls/ - call log ingestion and artifacts
- cases/ - case record, memory, SLA, linking
- channels/ - email and whatsapp providers, endpoints and connections
- inbound/ - inbound webhook connectors, delivery tracking, routing rules
- integrations/ - MCP integrations and tool discovery
- webhooks/ - webhook tools and secrets
- billing/ - plans, entitlements, usage, razorpay integration
- telephony/ - phone numbers, provider adapters
- policies/ - cross-cutting policy normalization
- workers/ - Oban jobs

## lib/swati_web

- router.ex - routes
- controllers/internal - internal APIs for runtimes
- live/ - LiveView UI
  - inbound_email_live/ - connector/rule/binding/replay management + `/inbound-email/inbox`
  - trust_console_live/inbound.ex - inbound delivery trust/replay console
  - sessions_live/show.ex - session thread detail + inbound routing/ownership panels

Important internal endpoints:
- POST /internal/v1/runtime/resolve
- POST /internal/v1/sessions/:session_id/events
- POST /internal/v1/sessions/:session_id/end
- POST /internal/v1/sessions/:session_id/artifacts
- POST /internal/v1/sessions/:session_id/timeline
- POST /internal/v1/channel-events

Important public inbound endpoint:
- POST /api/v1/inbound/:connector_token

Details: ../design-docs/internal_runtime_config.md
