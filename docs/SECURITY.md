# SECURITY

This repo contains infrastructure for handling customer communications.
Security rules are non-negotiable and must be explicit for agents.

Last updated: 2026-02-24

## Secrets and configuration

- Never commit secrets.
- All secrets come from environment variables in production.
- Swati.Vault uses a base64 key in SWATI_VAULT_KEY_B64.
- Internal API auth uses SWATI_INTERNAL_API_TOKEN and must match between control and data plane.

Runbook: references/production_system_setup.md

## Internal APIs

- Internal endpoints are under /internal/v1/ and are protected by SwatiWeb.Plugs.VerifyInternalToken.
- Treat internal APIs as public contracts between planes. Stable error codes and versioned responses.

Design doc: design-docs/internal_runtime_config.md

## Webhooks and integrations

- Prefer allowlists over open tool execution.
- Always set explicit timeouts.
- Treat all external payloads as untrusted. Normalize and validate before side effects.
- Do not log secrets. Redact headers and tokens.

## PII and logging

- Avoid logging raw customer emails, phone numbers, and message content unless required for debugging.
- If logging message content is necessary, gate it behind a policy and retention window.

## Review triggers

Escalate to a human reviewer when:
- a change touches authentication, authorization, token handling, or encryption
- a change affects data deletion or retention
- a change expands tool capabilities or relaxes allowlists