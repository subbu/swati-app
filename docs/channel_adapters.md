# Channel Adapters (Control Plane)

Read when: building non-voice channel adapters or wiring inbound/outbound channel events.

## Internal endpoints

All endpoints require `authorization: Bearer <SWATI_INTERNAL_API_TOKEN>`.

### Inbound channel events

`POST /internal/v1/channel-events`

Example:

```json
{
  "channel_key": "whatsapp",
  "endpoint_address": "+15550001111",
  "from_address": "+15550002222",
  "session_external_id": "thread-123",
  "direction": "inbound",
  "event": {
    "type": "channel.message.received",
    "payload": {"text": "Hi"}
  }
}
```

Response:

```json
{
  "runtime": {"config_version": 4, "session": {"id": "..."}},
  "session_id": "...",
  "case_id": "...",
  "customer_id": "..."
}
```

### Outbound send request (audit only)

`POST /internal/v1/channel-actions/send`

```json
{
  "session_id": "...",
  "text": "We received your request."
}
```

Response:

```json
{"session_id": "..."}
```
