defmodule Swati.Billing.Grace do
  require Logger

  alias Swati.Billing.Queries
  alias Swati.Repo
  alias Swati.Tenancy.Tenants

  def schedule_grace_enforcement(subscription) do
    now = DateTime.utc_now()

    if subscription.grace_expires_at &&
         DateTime.compare(subscription.grace_expires_at, now) == :gt do
      %{"tenant_subscription_id" => subscription.id, "reason" => "grace_expired"}
      |> Swati.Workers.EnforceSubscriptionGrace.new(
        scheduled_at: subscription.grace_expires_at,
        queue: :billing,
        unique: [fields: [:args], period: 86_400]
      )
      |> Oban.insert()

      :ok
    else
      enforce(subscription.id, "grace_expired")
    end
  end

  def schedule_end_suspension(subscription) do
    now = DateTime.utc_now()

    if subscription.current_end_at && DateTime.compare(subscription.current_end_at, now) == :gt do
      %{"tenant_subscription_id" => subscription.id, "reason" => "term_end"}
      |> Swati.Workers.EnforceSubscriptionGrace.new(
        scheduled_at: subscription.current_end_at,
        queue: :billing,
        unique: [fields: [:args], period: 86_400]
      )
      |> Oban.insert()

      :ok
    else
      enforce(subscription.id, "term_end")
    end
  end

  def enforce(tenant_subscription_id, reason) when is_binary(reason) do
    subscription =
      tenant_subscription_id
      |> Queries.get_tenant_subscription!()
      |> Repo.preload(:tenant)

    case reason do
      "grace_expired" ->
        enforce_grace_expired(subscription)

      "term_end" ->
        enforce_term_end(subscription)

      _ ->
        Logger.info("billing grace enforcement skipped reason=#{reason}")
        :ok
    end
  end

  defp enforce_grace_expired(subscription) do
    now = DateTime.utc_now()

    if subscription.grace_expires_at &&
         DateTime.compare(subscription.grace_expires_at, now) != :gt do
      case subscription.status do
        "pending" -> suspend_tenant(subscription)
        "halted" -> suspend_tenant(subscription)
        "paused" -> suspend_tenant(subscription)
        _ -> :ok
      end
    else
      :ok
    end
  end

  defp enforce_term_end(subscription) do
    now = DateTime.utc_now()

    if subscription.current_end_at && DateTime.compare(subscription.current_end_at, now) != :gt do
      case subscription.status do
        "cancelled" -> suspend_tenant(subscription)
        "completed" -> suspend_tenant(subscription)
        "expired" -> suspend_tenant(subscription)
        _ -> :ok
      end
    else
      :ok
    end
  end

  defp suspend_tenant(subscription) do
    case Tenants.update_billing_status(subscription.tenant, "suspended") do
      {:ok, _tenant} -> :ok
      {:error, reason} -> Logger.warning("billing suspend failed reason=#{inspect(reason)}")
    end
  end
end
