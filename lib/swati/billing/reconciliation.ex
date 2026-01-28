defmodule Swati.Billing.Reconciliation do
  require Logger

  import Ecto.Query, warn: false

  alias Swati.Billing.{Management, Plans, Razorpay, TenantSubscription}
  alias Swati.Repo

  @provider "razorpay"

  def reconcile_all do
    from(s in TenantSubscription,
      where: s.provider == ^@provider,
      where: s.status in ["active", "pending", "halted", "paused"]
    )
    |> Repo.all()
    |> Enum.each(&reconcile_subscription/1)

    :ok
  end

  defp reconcile_subscription(%TenantSubscription{} = subscription) do
    case Razorpay.fetch_subscription(subscription.provider_subscription_id) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        plan_code =
          case Plans.get_by_provider_plan_id(@provider, body["plan_id"]) do
            %{code: code} -> code
            _ -> subscription.plan_code
          end

        provider_attrs = %{
          provider: @provider,
          provider_subscription_id: subscription.provider_subscription_id,
          provider_customer_id: body["customer_id"],
          provider_plan_id: body["plan_id"],
          provider_status: body["status"],
          quantity: body["quantity"] || subscription.quantity,
          current_start_at: Razorpay.timestamp_to_datetime(body["current_start"]),
          current_end_at: Razorpay.timestamp_to_datetime(body["current_end"]),
          next_charge_at: Razorpay.timestamp_to_datetime(body["charge_at"]),
          cancelled_at: Razorpay.timestamp_to_datetime(body["cancelled_at"])
        }

        tenant_attrs = %{
          tenant_id: subscription.tenant_id,
          provider: subscription.provider,
          provider_subscription_id: subscription.provider_subscription_id,
          plan_code: plan_code,
          status: Razorpay.map_status(body["status"]),
          quantity: body["quantity"] || subscription.quantity,
          current_start_at: Razorpay.timestamp_to_datetime(body["current_start"]),
          current_end_at: Razorpay.timestamp_to_datetime(body["current_end"]),
          next_charge_at: Razorpay.timestamp_to_datetime(body["charge_at"]),
          cancelled_at: Razorpay.timestamp_to_datetime(body["cancelled_at"]),
          payment_method: subscription.payment_method,
          has_scheduled_changes: subscription.has_scheduled_changes,
          change_scheduled_at: subscription.change_scheduled_at,
          pending_plan_code: subscription.pending_plan_code,
          short_url: subscription.short_url,
          metadata:
            Map.merge(subscription.metadata || %{}, %{
              "reconciled_at" => DateTime.to_iso8601(DateTime.utc_now())
            })
        }

        _ = Management.upsert_provider_subscription(provider_attrs)
        _ = Management.upsert_tenant_subscription(tenant_attrs)
        :ok

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("razorpay reconcile failed status=#{status} body=#{inspect(body)}")

      {:error, reason} ->
        Logger.warning("razorpay reconcile error=#{inspect(reason)}")
    end
  end
end
