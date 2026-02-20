# Production System Setup

Read when: onboarding to prod infra, debugging prod routing/runtime issues, planning deploy changes.

Last verified: 2026-02-16 on host `e2e` (`e2e-130-182`).

## Overview

Production runs on a single Ubuntu VM with Docker Compose stacks.

Not Fly.

Main components:
- Nginx (host) as public ingress/TLS terminator
- Swati control plane + Postgres (`swati-control` compose project)
- Swati data plane blue/green + Redis (`swati-data` compose project)
- Caddy container exists, but currently fronts `simplyguest` only (not Swati domains)

## Host layout

Compose roots:
- `/srv/swati-control`
- `/srv/swati-data`
- `/srv/caddy`

Control-plane code:
- `/srv/swati-control/swati-app`

Data-plane code:
- `/srv/swati-data/swati-data-plane`

## Running containers

Current expected container names:
- `swati-control-control-plane-1`
- `swati-control-db-1`
- `swati-data-data-plane-blue-1`
- `swati-data-data-plane-green-1`
- `swati-data-redis-1`

Also present:
- `caddy-caddy-1` (not routing Swati)

## Ingress and routing

Host Nginx drives Swati traffic:

- `app.swati.ai` -> `http://127.0.0.1:4000` (control plane)
- `voice.swati.ai` -> `http://voice_backend` upstream (data plane active color)

Voice upstream files:
- `/etc/nginx/swati/voice-upstream-blue.conf` -> `127.0.0.1:8001`
- `/etc/nginx/swati/voice-upstream-green.conf` -> `127.0.0.1:8002`
- Active symlink: `/etc/nginx/conf.d/10-voice-upstream.conf`

WebSocket headers/timeouts are configured in `voice.swati.ai` Nginx site config.

## Internal networking

Control/data plane cross-network:
- external Docker network: `swati_cp_dp`
- control-plane static IP: `10.77.0.2`
- data-plane blue static IP: `10.77.0.3`
- data-plane green static IP: `10.77.0.4`

Data plane uses:
- `CONTROL_PLANE_BASE_URL=http://10.77.0.2:4000`

## Persistent data paths

- Postgres data: `/data/swatiai/postgres`
- Shared artefacts: `/data/swatiai/artefacts`
- Data-plane Redis AOF: `/data/swatiai/dp-redis`
- Data-plane logs: `/data/swatiai/dp-logs`

## Environment variables (keys only)

Control plane (`/srv/swati-control/.env`):
- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `FLUXON_LICENSE_KEY`
- `RESEND_API_KEY`
- `PLIVO_AUTH_ID`
- `PLIVO_AUTH_TOKEN`
- `MEDIA_GATEWAY_BASE_URL`
- `MEDIA_PUBLIC_BASE_URL`
- `S3_URL`
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`
- `SWATI_AVATAR_S3_BUCKET`
- `SWATI_AVATAR_S3_REGION`
- `SWATI_INTERNAL_API_TOKEN`
- `SWATI_VAULT_KEY_B64`
- `REPLICATE_API_TOKEN`

Data plane (`/srv/swati-data/.env`):
- `SWATI_INTERNAL_API_TOKEN`
- `GOOGLE_API_KEY`
- `GOOGLE_LIVE_MODEL`
- `GOOGLE_LIVE_WSS_URL`
- `PLIVO_PLAY_SAMPLE_RATE`
- `ENABLE_INPUT_AUDIO_TRANSCRIPTION`
- `ENABLE_OUTPUT_AUDIO_TRANSCRIPTION`
- `ENABLE_GOOGLE_SEARCH_TOOL`
- `SEND_INITIAL_GREETING`
- `INPUT_AUDIO_FRAME_MS`
- `INPUT_AUDIO_SAMPLE_RATE`
- `ENABLE_CALL_RECORDING`
- `RECORD_CALLER_AUDIO`
- `RECORD_AGENT_AUDIO`
- `GENERATE_STEREO_WAV`
- `MEDIA_PUBLIC_BASE_URL`
- `S3_CALL_RECORDINGS_BUCKET`
- `S3_URL`
- `S3_ACCESS_KEY`
- `S3_SECRET_KEY`

Critical invariant:
- `SWATI_INTERNAL_API_TOKEN` must match in control-plane and data-plane env.

## Day-to-day commands

Control plane:
```bash
docker compose -f /srv/swati-control/docker-compose.yml ps
docker logs -f swati-control-control-plane-1
docker logs -f swati-control-db-1
```

Data plane:
```bash
docker compose -f /srv/swati-data/docker-compose.yml ps
docker logs -f swati-data-data-plane-blue-1
docker logs -f swati-data-data-plane-green-1
docker logs -f swati-data-redis-1
```

Blue/green status/switch:
```bash
/srv/swati-data/ops/voice-bluegreen-status.sh
sudo /srv/swati-data/ops/voice-bluegreen-switch.sh blue
sudo /srv/swati-data/ops/voice-bluegreen-switch.sh green
```

## Deploy model

Control plane:
- rebuild/recreate `control-plane` service from `/srv/swati-control/swati-app`

Data plane:
- deploy standby color
- health check standby
- switch Nginx upstream symlink via switch script
- rollback by switching back

Reference runbooks on host:
- `/srv/swati-control/RUNBOOK.md`
- `/srv/swati-data/RUNBOOK.md`

## Known gotchas

- Control-plane container may show `unhealthy` if healthcheck tooling (`wget`) is missing, even when app serves traffic.
- DB restore/import can leave runtime wiring empty (`channels/endpoints/agent_channels` missing while `phone_numbers` exist). Symptoms: runtime resolve `endpoint_not_found` (404).
- Fast reconcile command (safe/idempotent) for wiring repair:

```bash
docker exec -i swati-control-control-plane-1 /app/bin/swati eval \
'Application.ensure_all_started(:swati);
 alias Swati.{Repo,Channels,Agents};
 alias Swati.Telephony.PhoneNumber;
 for pn <- Repo.all(PhoneNumber) do
   {:ok, ch} = Channels.ensure_voice_channel(pn.tenant_id);
   {:ok, _ep} = Channels.ensure_endpoint_for_phone_number(pn);
   if is_binary(pn.inbound_agent_id),
     do: Agents.upsert_agent_channel(pn.inbound_agent_id, ch.id, true, %{"mode" => "all"});
 end'
```
