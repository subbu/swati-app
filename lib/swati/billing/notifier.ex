defmodule Swati.Billing.Notifier do
  import Swoosh.Email

  alias Swati.Mailer

  def deliver_grace_notification(recipients, tenant, subscription, kind, grace_expires_at)
      when is_list(recipients) do
    subject = grace_subject(kind, tenant)
    body = grace_body(kind, tenant, subscription, grace_expires_at)

    email =
      new()
      |> to(recipients)
      |> from({"SimplyGuest", "noreply@simplyguest.com"})
      |> subject(subject)
      |> text_body(body)

    Mailer.deliver(email)
  end

  defp grace_subject(kind, tenant) do
    prefix =
      case kind do
        "grace_168h" -> "Final reminder"
        "grace_144h" -> "Payment issue reminder"
        _ -> "Payment issue"
      end

    "#{prefix}: #{tenant.name} subscription"
  end

  defp grace_body(kind, tenant, subscription, grace_expires_at) do
    readable_grace =
      if grace_expires_at do
        DateTime.to_string(grace_expires_at)
      else
        "soon"
      end

    line =
      case kind do
        "grace_168h" -> "Final reminder: grace period ends at #{readable_grace}."
        _ -> "Grace period ends at #{readable_grace}."
      end

    """

    ==============================

    Hi #{tenant.name} team,

    We couldn’t process the latest subscription payment for #{tenant.name}.
    Subscription ID: #{subscription.provider_subscription_id}

    #{line}

    Please update your payment method to avoid service suspension.

    ==============================
    """
  end
end
