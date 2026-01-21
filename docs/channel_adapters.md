# Channel Adapters (Control Plane)

Read when: building non-voice channel adapters or wiring inbound/outbound channel events.

## Channel connections

- OAuth connections live in `channel_connections` and store provider tokens in `secrets`.
- Use `Swati.Channels.ensure_email_channel/1` and `Swati.Channels.ensure_endpoint/4` to register an address.
- Gmail OAuth flow: `/channels/gmail/connect` → `/channels/gmail/callback` (authenticated scope).
- Outlook OAuth flow: `/channels/outlook/connect` → `/channels/outlook/callback` (authenticated scope).
- IMAP/SMTP connections are saved via the Channels UI and stored in `secrets` as JSON.
- Zoho Mail uses the IMAP/SMTP preset with `imap.zoho.com`/`smtp.zoho.com`.

### Sync schedule

- Email sync is queued via Oban Cron (default every 5 minutes).
- Use `Swati.Channels.sync_connection/1` for immediate sync when testing.

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

### Outbound send request

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

Notes:

- Email channels with Gmail, Outlook, or IMAP connections will send via the provider and append the event.
- Other channels currently only append an audit event.
