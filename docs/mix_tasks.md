# Mix Tasks

Operational Mix tasks for one-off maintenance and backfills.

## Usage

Run tasks with `MIX_ENV=prod` in production:

```bash
MIX_ENV=prod mix task.name --flag value
```

## Tasks

### Backport a provisioned phone number

Task: `mix swati.backport_phone_number`

Use when the number is already provisioned in Plivo and you need it in the DB.

Required:
- `--e164`
- `--country`
- One of: `--tenant-id`, `--user-id`, `--user-email`

Optional:
- `--region`
- `--provider` (default: `plivo`)
- `--provider-number-id` (default: digits from `--e164`)
- `--status` (default: `provisioned`)
- `--inbound-agent-id`
- `--update` (update if the number already exists)
- `--dry-run` (print attrs only)

Examples:

```bash
MIX_ENV=prod mix swati.backport_phone_number \
  --e164 +918035739111 \
  --country IN \
  --region Bangalore \
  --user-id 1
```

```bash
MIX_ENV=prod mix swati.backport_phone_number \
  --e164 +918035739111 \
  --country IN \
  --tenant-id <tenant-uuid> \
  --update
```

Notes:
- `--user-id` accepts a UUID or a 1-based index (ordered by `users.inserted_at`).
- If the user belongs to multiple tenants, pass `--tenant-id`.

### Backfill session agents

Task: `mix swati.backfill_session_agents`

Backfills `sessions.agent_id` using `case.assigned_agent_id`, endpoint routing defaults,
or a fallback published agent.

Optional:
- `--tenant-id`
- `--dry-run` (print rows only)

Examples:

```bash
MIX_ENV=prod mix swati.backfill_session_agents --tenant-id <tenant-uuid>
```

```bash
MIX_ENV=prod mix swati.backfill_session_agents --dry-run
```

### Normalize phone number E164 values

Task: `mix swati.backfill_phone_numbers`

Normalizes `phone_numbers.e164` to `+<digits>` format. Useful after legacy imports.
