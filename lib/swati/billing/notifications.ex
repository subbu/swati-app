defmodule Swati.Billing.Notifications do
  require Logger

  alias Swati.Billing.{BillingNotification, Config, Notifier, Queries, TenantSubscription}
  alias Swati.Repo
  alias Swati.Tenancy.Memberships

  @grace_notification_prefix "grace_"

  def schedule_grace_notifications(%TenantSubscription{} = subscription) do
    grace_expires_at = subscription.grace_expires_at

    if grace_expires_at do
      grace_days = Config.grace_period_days()
      start_at = DateTime.add(grace_expires_at, -grace_days * 86_400, :second)

      Config.grace_notification_offsets_hours()
      |> Enum.each(fn offset ->
        kind = grace_kind(offset)
        scheduled_at = DateTime.add(start_at, offset * 3_600, :second)
        scheduled_at = clamp_to_now(scheduled_at)

        %{"tenant_subscription_id" => subscription.id, "kind" => kind}
        |> Swati.Workers.SendBillingNotification.new(
          scheduled_at: scheduled_at,
          queue: :billing,
          unique: [fields: [:args], period: 86_400]
        )
        |> Oban.insert()
      end)
    end

    :ok
  end

  def send_notification(tenant_subscription_id, kind) when is_binary(kind) do
    subscription =
      tenant_subscription_id
      |> Queries.get_tenant_subscription!()
      |> Repo.preload(:tenant)

    case ensure_notification_record(subscription, kind) do
      {:ok, %BillingNotification{} = notification} ->
        deliver_notification(subscription, notification)

      {:error, :already_sent} ->
        :ok
    end
  end

  defp ensure_notification_record(%TenantSubscription{} = subscription, kind) do
    changeset =
      BillingNotification.changeset(%BillingNotification{}, %{
        tenant_id: subscription.tenant_id,
        tenant_subscription_id: subscription.id,
        kind: kind,
        status: "pending",
        scheduled_at: DateTime.utc_now()
      })

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: [:tenant_subscription_id, :kind],
           returning: [:id]
         ) do
      {:ok, %BillingNotification{id: nil}} -> {:error, :already_sent}
      {:ok, notification} -> {:ok, notification}
      {:error, _} = error -> error
    end
  end

  defp deliver_notification(
         %TenantSubscription{} = subscription,
         %BillingNotification{} = notification
       ) do
    recipients = Memberships.list_owner_emails(subscription.tenant_id)

    if recipients == [] do
      mark_notification(notification, "skipped", "no_recipients")
    else
      case Notifier.deliver_grace_notification(
             recipients,
             subscription.tenant,
             subscription,
             notification.kind,
             subscription.grace_expires_at
           ) do
        {:ok, _email} ->
          mark_notification(notification, "sent", nil)

        {:error, reason} ->
          Logger.warning("billing notification failed reason=#{inspect(reason)}")
          mark_notification(notification, "failed", inspect(reason))
      end
    end
  end

  defp mark_notification(notification, status, error) do
    notification
    |> BillingNotification.changeset(%{
      status: status,
      error: error,
      sent_at: if(status == "sent", do: DateTime.utc_now(), else: nil)
    })
    |> Repo.update()

    :ok
  end

  defp grace_kind(offset) do
    if offset == 0 do
      "#{@grace_notification_prefix}0h"
    else
      "#{@grace_notification_prefix}#{offset}h"
    end
  end

  defp clamp_to_now(%DateTime{} = scheduled_at) do
    now = DateTime.utc_now()
    if DateTime.compare(scheduled_at, now) == :lt, do: now, else: scheduled_at
  end
end
