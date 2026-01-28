defmodule Swati.Billing do
  alias Swati.Billing.{
    Enforcement,
    Invoices,
    Plans,
    Reconciliation,
    Subscriptions,
    Usage,
    Webhooks
  }

  alias Swati.Calls.Call

  def ingest_razorpay_webhook(params, raw_body) when is_map(params) and is_binary(raw_body) do
    Webhooks.ingest_razorpay(params, raw_body)
  end

  def process_subscription_event(event_id) do
    Webhooks.process_event(event_id)
  end

  def ensure_phone_number_limit(tenant_id) do
    Enforcement.ensure_phone_number_limit(tenant_id)
  end

  def ensure_integration_limit(tenant_id) do
    Enforcement.ensure_integration_limit(tenant_id)
  end

  def record_call_minutes(%Call{} = call) do
    Usage.record_call_minutes(call)
  end

  def refresh_usage_counts(tenant_id) do
    _ = Usage.refresh_phone_numbers(tenant_id)
    _ = Usage.refresh_integrations(tenant_id)
    :ok
  end

  def reconcile_subscriptions do
    Reconciliation.reconcile_all()
  end

  def subscription_for_tenant(tenant_id) do
    Subscriptions.current_for_tenant(tenant_id)
  end

  def upcoming_subscription_for_tenant(tenant_id) do
    Subscriptions.upcoming_for_tenant(tenant_id)
  end

  def list_plans do
    Plans.list_active_plans()
  end

  def change_plan(tenant, plan_code, timing \\ :now) do
    Subscriptions.change_plan(tenant, plan_code, timing)
  end

  def cancel_subscription(tenant, cancel_at_cycle_end \\ true) do
    Subscriptions.cancel(tenant, cancel_at_cycle_end)
  end

  def cancel_scheduled_change(tenant) do
    Subscriptions.cancel_scheduled_change(tenant)
  end

  def pay_again(tenant, plan_code) do
    Subscriptions.pay_again(tenant, plan_code)
  end

  def usage_summary(tenant_id) do
    Usage.summary(tenant_id)
  end

  def list_invoices(subscription_id, count \\ 10) do
    Invoices.list_for_subscription(subscription_id, count)
  end
end
