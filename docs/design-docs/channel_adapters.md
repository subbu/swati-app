# Channel Adapters (Control Plane)

Read when: building non-voice channel adapters or wiring inbound/outbound channel events.

## Channel connections

- OAuth connections live in `channel_connections` and store provider tokens in `secrets`.
- Use `Swati.Channels.ensure_email_channel/1` and `Swati.Channels.ensure_endpoint/4` to register an address.
- Gmail OAuth flow: `/channels/gmail/connect` → `/channels/gmail/callback` (authenticated scope).
- Outlook OAuth flow: `/channels/outlook/connect` → `/channels/outlook/callback` (authenticated scope).
- IMAP/SMTP connections are saved via the Channels UI and stored in `secrets` as JSON.
- Zoho Mail uses the IMAP/SMTP preset with `imap.zoho.com`/`smtp.zoho.com`.
- WhatsApp uses embedded signup in `/surfaces`, stores tokens in `secrets` (name `channel:whatsapp:waba:<id>`), and writes one connection per phone number.
- Template lifecycle UX is available at `/surfaces/whatsapp/templates`:
  - list/create templates (`whatsapp_business_management`)
  - send template messages to test numbers (`whatsapp_business_messaging`)
  - view delivery evidence timeline backed by `whatsapp_template_messages`

### WhatsApp webhooks

- Verification + events live at `/api/v1/webhooks/whatsapp`.
- Configure `WHATSAPP_WEBHOOK_VERIFY_TOKEN` and (optionally) `WHATSAPP_WEBHOOK_CALLBACK_URL`.
- Inbound messages are normalized into `channel.message.received` events.
- Outbound sends use the WhatsApp Cloud API via `channel-actions/send`.
- Delivery status webhooks (`messages.statuses`) update evidence rows keyed by Meta message id (`wamid`).

### Sync schedule

- Email sync is queued via Oban Cron (default every 5 minutes).
- Use `Swati.Channels.sync_connection/1` for immediate sync when testing.

### Inbound email connectors (webhook intake)

- Provider-agnostic webhook intake lives at `POST /api/v1/inbound/:connector_token`.
- Current adapter: Resend (`email.received`) with Svix signature verification headers.
- Intake is feature-gated by `config :swati, inbound_connectors_v1: true`.
- Configure connectors and rules in `/inbound-email`.
- `/inbound-email` also manages:
  - address bindings (`to address -> default owner`)
  - route preview (dry run using connector + envelope fields)
  - delivery replay for failed/processed records
- Tenant-facing inbox view is at `/inbound-email/inbox`:
  - message-level list across `channel.message.received` and `channel.message.sent`
  - filters by direction, owner agent, case id, and text query
  - links each message to its session and case
- Trust delivery workflow is at `/trust/inbound`:
  - delivery health list with filters (status, connector, sender, search)
  - signature result, processing errors, route details, and replay
- Connector routing order:
  1) continuity (`session_external_id` thread hit)
  2) endpoint default agent
  3) agent inbound rules (`agent_inbound_rules`)
  4) connector default agent / tenant fallback
- Rule matching normalizes email addresses (case-insensitive, supports `Name <email@domain>` forms).
- Endpoint lookup for inbound routing is tenant-scoped to avoid cross-tenant address collisions.
- Deliveries and route decisions are stored in `inbound_deliveries`.
- Session-level routing audit is written to:
  - `sessions.metadata.inbound_routing`
  - session event `inbound.routing.resolved`
- Ownership continuity audit is written to:
  - `inbound_thread_ownership_events`
  - session event `inbound.ownership.changed`
- Accepted handoffs can transfer owner when `target_agent_id` is present in resolve metadata.
- Connectors are stored in `inbound_connectors`; signing secrets in `secrets`.

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
- Inbound webhook email also normalizes to `channel.message.received` and uses the same ingestion/runtime path.
- Telemetry emitted:
  - `[:swati, :inbound, :webhook, :ingest]`
  - `[:swati, :inbound, :delivery, :process]`
  - `[:swati, :inbound, :delivery, :replay]`
- Other channels currently only append an audit event.
