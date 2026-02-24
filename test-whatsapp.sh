#!/usr/bin/env bash
set -euo pipefail

TOKEN='EAAJrZAeAOb7cBQZCtEtoddm9jZBOffSvZB2Sn8LnZAM7i7VJZAEmt5uWH6Vs2n7L0uESZCLv25aVcDZBON6n2wITZBrUUuZCgVfZAzvRSbZBbd9Vt1X90CatmzpfJq2UbGOO5v9pdDuv2BwE7AyPaktixkYT3ofNiw8ABfgVJCcIV7RZCEPIktKo0kZAtDfNBtvpXcgnK3g7ejAsauZBPy4736KsqN8zhk5RnGdZCYIVq2OgTjXeQZBN1sfYuBiuirU38Au5qVDZCTJq2ilrkFOI3eVhMRauTZCYgZDZD'
CONFIGURED_PHONE_ID='932721583266901'
CONFIGURED_WABA_ID='25825842880408390'

GRAPH_VERSION="${GRAPH_VERSION:-v22.0}"
TO="${TO:-919663057700}"
TEMPLATE_NAME="${TEMPLATE_NAME:-hello_world}"
TEMPLATE_LANG="${TEMPLATE_LANG:-en_US}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

require_cmd curl
require_cmd jq

graph_get() {
  local path="$1"
  curl -sS -H "Authorization: Bearer ${TOKEN}" \
    "https://graph.facebook.com/${GRAPH_VERSION}/${path}"
}

graph_post() {
  local path="$1"
  local body="$2"

  curl -sS -X POST \
    -H "Authorization: Bearer ${TOKEN}" \
    -H 'Content-Type: application/json' \
    "https://graph.facebook.com/${GRAPH_VERSION}/${path}" \
    -d "${body}"
}

debug_token() {
  curl -sS "https://graph.facebook.com/${GRAPH_VERSION}/debug_token?input_token=${TOKEN}&access_token=${TOKEN}"
}

print_json() {
  jq . <<<"$1"
}

fail_if_error() {
  local response="$1"
  local label="$2"

  if jq -e '.error' >/dev/null <<<"$response"; then
    echo "${label} failed"
    print_json "$response"
    exit 1
  fi
}

pick_active_waba_id() {
  local debug_response="$1"
  local token_waba_id

  token_waba_id=$(jq -r '
    .data.granular_scopes[]?
    | select(.scope == "whatsapp_business_messaging")
    | .target_ids[0] // empty
  ' <<<"$debug_response" | head -n 1)

  if [[ -n "${WABA_ID_OVERRIDE:-}" ]]; then
    echo "$WABA_ID_OVERRIDE"
    return
  fi

  if [[ -n "$token_waba_id" ]]; then
    echo "$token_waba_id"
    return
  fi

  echo "$CONFIGURED_WABA_ID"
}

pick_active_phone_id() {
  local phones_response="$1"

  if [[ -n "${PHONE_ID_OVERRIDE:-}" ]]; then
    echo "$PHONE_ID_OVERRIDE"
    return
  fi

  if jq -e --arg id "$CONFIGURED_PHONE_ID" '.data[]? | select(.id == $id)' >/dev/null <<<"$phones_response"; then
    echo "$CONFIGURED_PHONE_ID"
    return
  fi

  jq -r '.data[0].id // empty' <<<"$phones_response"
}

DEBUG_RESPONSE=$(debug_token)
fail_if_error "$DEBUG_RESPONSE" 'debug_token'

IS_VALID=$(jq -r '.data.is_valid // false' <<<"$DEBUG_RESPONSE")
if [[ "$IS_VALID" != "true" ]]; then
  echo 'Token is invalid'
  print_json "$DEBUG_RESPONSE"
  exit 1
fi

TOKEN_WABA_ID=$(jq -r '
  .data.granular_scopes[]?
  | select(.scope == "whatsapp_business_messaging")
  | .target_ids[0] // empty
' <<<"$DEBUG_RESPONSE" | head -n 1)

ACTIVE_WABA_ID=$(pick_active_waba_id "$DEBUG_RESPONSE")

echo "Configured WABA ID: ${CONFIGURED_WABA_ID}"
echo "Token-scoped WABA ID: ${TOKEN_WABA_ID:-<none>}"
echo "Active WABA ID: ${ACTIVE_WABA_ID}"

WABA_RESPONSE=$(graph_get "${ACTIVE_WABA_ID}?fields=id,name")
fail_if_error "$WABA_RESPONSE" 'WABA lookup'

echo 'WABA'
print_json "$WABA_RESPONSE"

PHONES_RESPONSE=$(graph_get "${ACTIVE_WABA_ID}/phone_numbers?fields=id,display_phone_number,verified_name")
fail_if_error "$PHONES_RESPONSE" 'WABA phone_numbers lookup'

echo 'Phone numbers under active WABA'
print_json "$PHONES_RESPONSE"

PHONE_COUNT=$(jq -r '.data | length' <<<"$PHONES_RESPONSE")
if [[ "$PHONE_COUNT" -eq 0 ]]; then
  echo 'No phone numbers attached to active WABA. Attach a sender first in WhatsApp Manager/API Setup.'
  exit 1
fi

ACTIVE_PHONE_ID=$(pick_active_phone_id "$PHONES_RESPONSE")
if [[ -z "$ACTIVE_PHONE_ID" ]]; then
  echo 'Could not resolve active phone ID'
  exit 1
fi

echo "Configured phone ID: ${CONFIGURED_PHONE_ID}"
echo "Active phone ID: ${ACTIVE_PHONE_ID}"

PHONE_RESPONSE=$(graph_get "${ACTIVE_PHONE_ID}?fields=id,display_phone_number,verified_name")
fail_if_error "$PHONE_RESPONSE" 'Phone lookup'

echo 'Phone'
print_json "$PHONE_RESPONSE"

if [[ "${SEND_TEST:-0}" == "1" ]]; then
  BODY=$(jq -nc \
    --arg to "$TO" \
    --arg template "$TEMPLATE_NAME" \
    --arg lang "$TEMPLATE_LANG" \
    '{
      messaging_product: "whatsapp",
      to: $to,
      type: "template",
      template: {
        name: $template,
        language: {code: $lang}
      }
    }')

  SEND_RESPONSE=$(graph_post "${ACTIVE_PHONE_ID}/messages" "$BODY")
  fail_if_error "$SEND_RESPONSE" 'Send template message'

  echo 'Send response'
  print_json "$SEND_RESPONSE"
fi

echo 'Checks passed'
