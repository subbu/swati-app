# Internal Runtime Config (Execution Plane)

Read when: changing runtime config shape or execution-plane ingestion.

## Auth

- Header: `authorization: Bearer <SWATI_INTERNAL_API_TOKEN>`
- All endpoints live under `/internal/v1/*`.

## Config versioning

- `config_version` is an integer constant.
- Increment `Swati.RuntimeConfig.version/0` when the response shape changes.

## Endpoints

### Resolve runtime config

`POST /internal/v1/runtime/resolve`

Request example:

```json
{
  "channel_key": "voice",
  "channel_type": "voice",
  "endpoint_address": "+91...",
  "from_address": "+91...",
  "session_external_id": "plivo-call-id",
  "direction": "inbound",
  "started_at": "2025-12-31T10:00:00.123456Z"
}
```

Response example:

```json
{
  "config_version": 5,
  "tenant": {"id": "...", "name": "...", "timezone": "Asia/Kolkata"},
  "channel": {
    "id": "...",
    "name": "Voice",
    "key": "voice",
    "type": "voice",
    "status": "active",
    "capabilities": {"tools": ["channel.message.send"]}
  },
  "endpoint": {
    "id": "...",
    "address": "+91...",
    "display_name": "+91...",
    "status": "active",
    "routing_policy": {"default_agent_id": "..."},
    "metadata": {"provider": "plivo"}
  },
  "customer": {
    "id": "...",
    "name": "...",
    "timezone": "Asia/Kolkata",
    "language": "en-IN",
    "preferences": {}
  },
  "case": {
    "id": "...",
    "status": "new",
    "priority": "normal",
    "category": "billing",
    "title": "Refund request",
    "summary": null,
    "memory": {"summary": null, "commitments": [], "constraints": [], "next_actions": []}
  },
  "case_linking": {
    "strategy": "open_case",
    "confidence": 0.78,
    "window_hours": 48,
    "within_window": true,
    "matched_category": true,
    "last_activity_at": "2026-01-19T17:23:52.456268Z",
    "category": "billing"
  },
  "session": {
    "id": "...",
    "status": "open",
    "direction": "inbound",
    "external_id": "plivo-call-id",
    "subject": null
  },
  "agent": {
    "id": "...",
    "name": "Front Desk",
    "language": "en-IN",
    "voice": {"provider": "google", "name": "Fenrir"},
    "llm": {"provider": "google", "model": "models/..."},
    "system_prompt": "...",
    "tool_policy": {
      "allow": ["search", "channel.message.send"],
      "deny": [],
      "max_calls_per_turn": 3
    },
    "tool_definitions": [
      {
        "name": "channel.message.send",
        "description": "Send a message to the current channel/session.",
        "parameters": {"type": "object", "properties": {"text": {"type": "string"}}}
      }
    ],
    "escalation_policy": {"enabled": true}
  },
  "integrations": [
    {
      "id": "...",
      "type": "mcp_streamable_http",
      "endpoint": "https://.../mcp",
      "origin": "https://...",
      "protocol_version": "2025-06-18",
      "timeout_secs": 15,
      "auth": {"type": "bearer", "token": "..."},
      "allowed_tools": ["search"]
    }
  ],
  "webhooks": [
    {
      "id": "...",
      "name": "Create ticket",
      "tool_name": "create_ticket",
      "description": "Open a support ticket",
      "endpoint": "https://.../tickets",
      "http_method": "post",
      "timeout_secs": 15,
      "status": "active",
      "headers": {"x-api-key": "********"},
      "input_schema": {
        "type": "object",
        "properties": {"subject": {"type": "string"}},
        "required": ["subject"]
      },
      "auth": {"type": "bearer", "token": "..."}
    }
  ],
  "logging": {
    "recording": {
      "enabled": true,
      "record_caller": true,
      "record_agent": true,
      "generate_stereo": true
    },
    "retention_days": 30
  },
  "policy": {
    "tool_policy": {
      "allow": ["search", "channel.message.send"],
      "deny": [],
      "max_calls_per_turn": 3
    },
    "tool_risk": {
      "refund.create": {
        "access": "write",
        "reversible": false,
        "financial": "high",
        "pii": "none",
        "requires_approval": true
      }
    },
    "logging": {"retention_days": 30},
    "case_linking": {
      "strategy": "open_case",
      "confidence": 0.78,
      "window_hours": 48,
      "within_window": true,
      "matched_category": true,
      "last_activity_at": "2026-01-19T17:23:52.456268Z",
      "category": "billing"
    }
  }
}
```

Notes:
- `tool_policy.allow` defaults to the union of tool names from enabled integrations, webhooks, and `channel.capabilities.tools` when the agent allowlist is empty.
- If the agent allowlist is set, the response filters it to tools present in those sources.
- `agent.tool_definitions` carries control-plane tool schemas (e.g., channel tools). The execution plane merges these with MCP tool schemas.
- Runtime resolution fails with `agent_channel_disabled` or `agent_channel_scope_denied` when the agent is not assigned to the channel or scoped away from the endpoint.
- `agent.system_prompt` is composed per call as Markdown: base agent instructions + call/customer/case context.
- Policies may add Markdown blocks with `system_prompt.prepend` or `system_prompt.append` in tenant/channel/case policy (applied in that order).

Error response:

```json
{
  "error": {
    "code": "agent_channel_disabled",
    "message": "Agent not enabled for channel.",
    "action": "enable_agent_channel",
    "retryable": false,
    "details": null
  }
}
```

Notes:
- `error.code` is the canonical failure code for programmatic handling.
- `error.action` is a suggested remediation for operators.
- `error.retryable` signals whether a retry is expected to succeed without config changes.

### Report runtime rejections

`POST /internal/v1/runtime/rejections`

Request example:

```json
{
  "provider": "plivo",
  "provider_call_id": "call-123",
  "session_external_id": "call-123",
  "endpoint_address": "+91...",
  "from_address": "+91...",
  "to_address": "+91...",
  "channel_key": "voice",
  "channel_type": "voice",
  "direction": "inbound",
  "occurred_at": "2026-01-22T10:00:00.123456Z",
  "error": {
    "code": "agent_channel_disabled",
    "message": "Agent not enabled for channel.",
    "action": "enable_agent_channel",
    "retryable": false
  }
}
```

### Session lifecycle

#### Append events

`POST /internal/v1/sessions/:session_id/events`

```json
{
  "events": [
    {
      "ts": "2025-12-31T10:00:01.123456Z",
      "type": "channel.message.received",
      "source": "channel",
      "idempotency_key": "event-1",
      "payload": {"text": "hi"}
    }
  ]
}
```

#### End session

`POST /internal/v1/sessions/:session_id/end`

```json
{
  "ended_at": "2025-12-31T10:02:00.123456Z",
  "status": "closed"
}
```

Notes:
- Timestamps must be RFC3339 with microsecond precision (e.g. `2026-01-01T08:00:01.000000Z`).
- `status` accepts session statuses (`open`, `active`, `waiting_on_customer`, `closed`). `cancelled`/`canceled` are treated as `closed`.

#### Artifacts

`POST /internal/v1/sessions/:session_id/artifacts`

```json
{
  "recording": {"stereo_url": "https://...", "caller_url": "...", "agent_url": "..."},
  "transcript": {"text_url": "https://...", "jsonl_url": "..."}
}
```

#### Timeline (voice)

`POST /internal/v1/sessions/:session_id/timeline`

```json
{
  "timeline": {
    "version": 1,
    "duration_ms": 123,
    "utterances": [],
    "speaker_segments": [],
    "tool_calls": [],
    "markers": []
  }
}
```
