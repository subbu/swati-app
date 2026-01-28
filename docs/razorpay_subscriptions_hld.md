# Razorpay subscriptions HLD

Read when: billing integration; subscription lifecycle; entitlement enforcement; usage tracking.

## Goals
- Reliable Razorpay webhook intake and reconciliation.
- Tenant-level subscription state and plan entitlements.
- Usage tracking for phone numbers, call minutes, integrations.
- Self-serve plan changes, cancel-at-cycle-end, pay-again flow.
- Show plan pricing and invoices in billing settings.
- Provider-agnostic billing data model (Razorpay today, Stripe later).

## Non-goals
- In-app checkout or payment method updates.
- Resume/reactivate subscriptions (manual via Razorpay only).

## Inputs (current)
- Razorpay plan IDs and names from dashboard:
  - starter: plan_S7yIQ3Y3D5NXUf
  - smart: plan_S7yJ5AeEvMaiDR
  - intelligent: plan_S7yVLR6xDQddwV
- Plan pricing seeded into billing_plans (amount in paisa + currency).
- Razorpay plan ids stored in billing_plan_providers.
- Subscription created on marketing site for new customers.
- Tenant created after payment capture from subscription/customer email.
- Payment method captured from webhook payload for UPI restrictions.
- Reference: https://razorpay.com/docs/payments/subscriptions/ (webhooks, states, APIs).

## Contexts and ownership
- New context: Swati.Billing (facade, commands, queries, policies, adapters).
- Tenancy: tenant status + plan code (string) + policy overrides.
- Telephony: phone numbers count and provisioning enforcement.
- Integrations: integrations count and creation enforcement.
- Calls: call minutes usage source.

## High-level architecture
1) Marketing site creates Razorpay subscription.
2) Razorpay sends webhooks -> Swati webhook endpoint.
3) Webhook ingest stores event, acks fast, queues processing job.
4) Processor updates subscription record, tenant plan/status, cycle dates.
5) Entitlement policy computed from plan + overrides.
6) Usage tracking writes usage counters per billing cycle.
7) Enforcement gates provisioning/integration creation and call usage.

## Webhook handling
- Endpoint: POST /v1/billing/razorpay/webhook
- Verify signature using Razorpay webhook secret and raw body.
- Store event in billing_events with unique provider_event_id + provider.
- Idempotent processing: skip if already processed.
- Async processing via Oban job for retries and backoff.
- On unknown tenant mapping: mark event as orphaned; alert; no state changes.
- Capture subscription metadata: payment_method, has_scheduled_changes, change_scheduled_at,
  pending_plan_code, short_url.

### Tenant mapping
- Marketing site passes plan metadata (plan_id/plan_name, source) only.
- Webhook processor resolves tenant by:
  1) Existing tenant_subscription by provider_subscription_id.
  2) BillingCustomer by provider_customer_id.
  3) Customer email -> existing tenant if user exists.
  4) Create user+tenant after captured payment using Accounts.Registration.
- If tenant missing and payment not captured yet, skip until activation.

### Event selection (configure in Razorpay)
- Subscribe to subscription lifecycle events and payment events for reliability.
- Use Razorpay "Subscribe to Webhooks" docs to pick the exact event list.
- Map to internal state transitions (see below).

## Subscription state mapping
Internal subscription_status:
- active
- pending (payment due / auth pending)
- paused
- halted (payment failed or retries exhausted)
- cancelled
- completed (natural end)
- expired

State updates:
- subscription.activated -> active + open cycle
- subscription.charged / payment.captured -> active + extend cycle
- subscription.pending / payment.failed -> pending or halted (policy)
- subscription.paused / subscription.halted -> paused or halted
- subscription.resumed -> active
- subscription.cancelled -> cancelled
- subscription.completed / subscription.expired -> completed or expired

## Plan management (settings/billing)
Plan change:
- Default timing: now; optional schedule_change_at=cycle_end.
- If timing == now, update tenant.plan immediately.
- If timing == cycle_end, store pending_plan_code; tenant.plan unchanged until webhook.

UPI restrictions:
- Razorpay blocks updates for UPI subscriptions.
- UI disables plan updates for UPI and guides to cancel at cycle end + pay again.

Cancel:
- Only cancel_at_cycle_end supported.
- No resume/reactivate flow.

Pay again:
- Create new subscription via Razorpay API with start_at=current_end_at.
- Store short_url in metadata; show “Complete payment” link.
- UPI pay-again disabled until current cycle ends.

Invoices:
- Fetch latest invoices by subscription_id from Razorpay /invoices.
- Display amount, status, date, and invoice ID.

Grace period:
- Default window: 7 days (configurable).
- On payment failure: keep tenant active during grace window.
- Notify at T0, T+24h, T+72h, T+6d, final at T+7d.
- On grace expiry: move tenant to suspended; keep subscription status as per provider.

## Data model (proposed)
billing_plans
- id, code, name, amount, currency, entitlements (json), status, inserted_at

billing_plan_providers
- id, plan_id, provider, provider_plan_id

billing_customers
- id, tenant_id, provider, provider_customer_id, email, contact, metadata

provider_subscriptions
- id, provider, provider_subscription_id, provider_customer_id, provider_plan_id
- provider_status, quantity, current_start_at, current_end_at, next_charge_at, cancelled_at, metadata

tenant_subscriptions
- id, tenant_id, provider, provider_subscription_id, plan_code, status, quantity
- current_start_at, current_end_at, next_charge_at, cancelled_at, grace_expires_at
- payment_method, has_scheduled_changes, change_scheduled_at, pending_plan_code, short_url
- metadata

billing_events
- id, provider, provider_event_id, event_type, payload (json)
- received_at, processed_at, processing_error

billing_cycles
- id, tenant_subscription_id, tenant_id
- start_at, end_at, status (open/closed), usage_summary (json)

billing_usage_counters
- id, tenant_id, cycle_id, metric, amount
- unique (cycle_id, metric)

billing_usage_events (optional, for audit)
- id, tenant_id, cycle_id, metric, amount, source_type, source_id, occurred_at

## Entitlements
Entitlements map (per plan):
- max_phone_numbers
- max_integrations
- included_call_minutes

Policy resolution:
- plan entitlements from billing_plans.entitlements
- tenant.policy.billing_overrides (optional)
- effective_entitlements = plan + overrides

Snapshot on cycle open:
- store effective_entitlements in billing_cycles.usage_summary

## Usage tracking
Phone numbers:
- Source: telephony.phone_numbers count where status != suspended/deleted.
- Track peak count per cycle for billing/limits.

Integrations:
- Source: integrations count per tenant (active only).
- Track current count and peak per cycle.

Call minutes:
- Source: calls table or call events when call ends.
- On call completion: emit usage_event metric=call_minutes, amount=ceil(seconds/60).
- Aggregate into billing_usage_counters for cycle.

## Enforcement points
Telephony provisioning:
- Before provision_phone_number: check effective_entitlements.max_phone_numbers.
- If over: block and return error with upgrade CTA.

Integrations creation:
- Before create_integration: check max_integrations.
- If over: block and return error.

Call minutes:
- Soft enforcement: allow calls when exceeded, mark overage, alert tenant.
- Track overage in usage_summary for billing/plan upgrade prompts.

## Reconciliation
- Daily job: fetch subscription by provider id (Req) and reconcile state.
- Backfill events or fix drift between Razorpay and DB.
- Manual admin action: reprocess orphaned events after mapping fix.

## Observability
- Log every webhook event with provider_event_id and tenant_id.
- Metrics: events_received, events_failed, processing_latency.
- Alert on signature failures and orphaned events.

## Security
- Verify Razorpay webhook signature (HMAC SHA256).
- Reject missing signature or invalid body.
- Store raw payload for audit (limit retention if needed).

## Open decisions
- Upgrade/downgrade proration (follow Razorpay settings).
