defmodule SwatiWeb.BillingCompleteHTML do
  @moduledoc """
  Post-payment completion page for marketing checkout redirects.
  """
  use SwatiWeb, :html

  embed_templates "billing_complete_html/*"

  def status_title(nil), do: "Processing payment"
  def status_title("active"), do: "Subscription active"
  def status_title("authenticated"), do: "Payment authenticated"
  def status_title("pending"), do: "Processing payment"
  def status_title("halted"), do: "Payment needs attention"
  def status_title("cancelled"), do: "Subscription cancelled"
  def status_title("completed"), do: "Subscription completed"
  def status_title("expired"), do: "Subscription expired"
  def status_title("paused"), do: "Subscription paused"
  def status_title(status), do: "Status: #{status}"

  def status_detail(nil),
    do: "We are confirming your payment and subscription. This usually takes a minute."

  def status_detail("active"),
    do: "Your payment is complete and the subscription is active."

  def status_detail("authenticated"),
    do: "Authorization succeeded. We are finalizing your subscription."

  def status_detail("pending"),
    do: "We are still confirming your payment. Please wait a moment."

  def status_detail("halted"),
    do: "The payment did not complete. Please try again from the billing page."

  def status_detail("cancelled"),
    do: "The subscription was cancelled and will remain inactive."

  def status_detail("completed"),
    do: "The subscription completed its billing cycle."

  def status_detail("expired"),
    do: "The subscription expired. Please restart from pricing."

  def status_detail("paused"),
    do: "The subscription is paused. Contact support if this is unexpected."

  def status_detail(_status),
    do: "We received your payment. Your status will update shortly."

  def status_value(tenant_subscription, provider_subscription) do
    cond do
      is_map(tenant_subscription) -> tenant_subscription.status
      is_map(provider_subscription) -> provider_subscription.provider_status
      true -> nil
    end
  end

  def plan_label(nil), do: "—"
  def plan_label(plan), do: plan.name

  def format_datetime(nil), do: "—"

  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%-d %b, %Y")
  end

  def cancellation_note(nil), do: nil

  def cancellation_note(%{cancelled_at: %DateTime{} = cancelled_at}) do
    "Cancellation scheduled for #{format_datetime(cancelled_at)}."
  end

  def cancellation_note(_subscription), do: nil
end
