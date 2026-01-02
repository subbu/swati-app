# Internal Runtime Config (Media Gateway)

## Auth

- Header: `authorization: Bearer <SWATI_INTERNAL_API_TOKEN>`
- All endpoints live under `/internal/v1/*`.

## Config versioning

- `config_version` is an integer constant.
- Increment `Swati.RuntimeConfig.version/0` when the response shape changes.

## Endpoints

### Resolve runtime config

`GET /internal/v1/runtime/phone_numbers/:phone_number_id`

Response example:

```json
{
  "config_version": 1,
  "tenant": {"id": "...", "name": "...", "timezone": "Asia/Kolkata"},
  "phone_number": {"id": "...", "e164": "+91...", "provider": "plivo"},
  "agent": {
    "id": "...",
    "name": "Front Desk",
    "language": "en-IN",
    "voice": {"provider": "google", "name": "Fenrir"},
    "llm": {"provider": "google", "model": "models/..."},
    "system_prompt": "...",
    "tool_policy": {"allow": [], "deny": [], "max_calls_per_turn": 3},
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
      "allowed_tools": ["search", "get_customer"]
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
  }
}
```

### Call lifecycle

#### Start call

`POST /internal/v1/calls/start`

```json
{
  "provider": "plivo",
  "provider_call_id": "...",
  "provider_stream_id": "...",
  "phone_number_id": "...",
  "from_number": "+91...",
  "to_number": "+91...",
  "started_at": "2025-12-31T10:00:00.123456Z"
}
```

Response:

```json
{"call_id": "<uuid>"}
```

#### Append events

`POST /internal/v1/calls/:call_id/events`

```json
{
  "events": [
    {"ts": "2025-12-31T10:00:01.123456Z", "type": "plivo_start", "payload": {}},
    {"ts": "2025-12-31T10:00:02.123456Z", "type": "tool_call", "payload": {}},
    {"ts": "2025-12-31T10:00:03.123456Z", "type": "transcript", "payload": {"tag": "CALLER", "text": "hi"}}
  ]
}
```

#### End call

`POST /internal/v1/calls/:call_id/end`

```json
{
  "ended_at": "2025-12-31T10:02:00.123456Z",
  "status": "ended",
  "duration_seconds": 123
}
```

Notes:
- Timestamps must be RFC3339 with microsecond precision (e.g. `2026-01-01T08:00:01.000000Z`).
- Status must be one of `ended`, `failed`, or `cancelled`.

#### Artifacts

`POST /internal/v1/calls/:call_id/artifacts`

```json
{
  "recording": {"stereo_url": "https://...", "caller_url": "...", "agent_url": "..."},
  "transcript": {"text_url": "https://...", "jsonl_url": "..."}
}
```
