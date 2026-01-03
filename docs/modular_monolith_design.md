# Modular Monolith Design (DDD-lite)

Read when: new feature touches multiple contexts; controller/liveview logic grows; refactor into smaller modules.

## Goals
- Single OTP app; explicit boundaries; no big-bang rewrite.
- Keep facades stable; move logic into smaller modules.
- Minimize god contexts; keep modules ~500 LOC.

## Bounded contexts (current)
- Identity: Accounts + Tenancy.
- Agent Studio: Agents, versions, tool/escalation policy.
- Tool Integrations: MCP config, secrets, tool discovery/testing.
- Telephony: numbers, provisioning, provider adapters.
- Call Log: calls, events, artifacts.
- Runtime Gateway: internal runtime config + call ingestion boundary.

## Layering pattern (Elixir-friendly)
Each context folder uses:
- Facade: `Swati.<Context>`; small public API.
- Commands: write paths, orchestration, Ecto.Multi.
- Queries: read paths, filters, preloads.
- Policies/Value Objects: normalize/validate/merge maps.
- Ports/Adapters: behaviours + external clients (Req, providers).

Web layer calls facades or application services. Avoid domain logic in controllers/liveviews.

## Runtime Gateway
- Builder: `Swati.Runtime.runtime_config_for_phone_number/1`.
- Tool policy: `Swati.Agents.ToolPolicy`.
- Integration payloads: `Swati.Integrations.Serialization`.
- Controller: `SwatiWeb.Internal.RuntimeController` delegates only.

## Integrations
- Facade: `Swati.Integrations`.
- Management: create/update/delete + audit (`Swati.Integrations.Management`).
- Secrets: bearer rules + upsert (`Swati.Integrations.Secrets`).
- MCP workflow: initialize/initialized/tools (`Swati.Integrations.MCP`).
- MCP client: behaviour + Req adapter (`Swati.Integrations.MCP.Client*`).
- Allowlist + prefix: `Swati.Integrations.ToolAllowlist`.

## Telephony
- Queries: `Swati.Telephony.Queries`.
- Commands: `Swati.Telephony.Commands`.
- Answer URL policy: `Swati.Telephony.AnswerUrl`.
- Status transitions: `Swati.Telephony.PhoneNumberStatusTransitions`.

## Calls ingestion
- Inbound parsing + normalization: `Swati.Calls.Ingestion`, `Swati.Calls.Events`.
- Controller delegates; parsing rules centralized.

## Accounts + Tenancy
- Facades: `Swati.Accounts`, `Swati.Tenancy`.
- Registration: `Swati.Accounts.Registration`.
- Auth: `Swati.Accounts.Auth.Session`, `Swati.Accounts.Auth.MagicLink`.
- Memberships: owned by `Swati.Tenancy.Memberships` (Accounts delegates).
- Tenants: `Swati.Tenancy.Tenants`.
- Role enforcement: `Swati.Tenancy.RoleNotAllowedError` for access violations.

## Policy modules (map-based, centralized)
- Tool policy: `Swati.Agents.ToolPolicy`.
- Escalation policy normalize: `Swati.Agents.EscalationPolicy`.
- Call/phone status transitions: `Swati.Calls.CallStatusTransitions`, `Swati.Telephony.PhoneNumberStatusTransitions`.

Rule: maps OK; interpretation belongs in policy modules, not controllers/liveviews.

## Contribution guide
- Add new logic in submodules; keep facades small and stable.
- New external calls: add a port behaviour + adapter; use Req.
- Queries should preload data used by templates.
- Add regression tests for bug fixes; prefer focused tests per module.
- Normalize map-based configs in one place (policy/attrs modules), then reuse.
