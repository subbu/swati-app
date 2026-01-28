defmodule Swati.Billing.Subscriptions do
  require Logger

  alias Swati.Billing.{
    Config,
    Error,
    Errors,
    Management,
    Plans,
    Queries,
    Razorpay,
    TenantSubscription
  }

  alias Swati.Tenancy.{Tenant, Tenants}

  @provider "razorpay"

  def current_for_tenant(tenant_id) when is_binary(tenant_id) do
    Queries.get_tenant_subscription_for_tenant(tenant_id)
  end

  def upcoming_for_tenant(tenant_id) when is_binary(tenant_id) do
    Queries.get_upcoming_subscription_for_tenant(tenant_id)
  end

  def change_plan(%Tenant{} = tenant, plan_code, timing \\ :now) when is_binary(plan_code) do
    subscription = current_for_tenant(tenant.id)
    plan = Plans.get_by_code(plan_code)
    provider_plan_id = Plans.get_provider_plan_id(plan_code, @provider)

    cond do
      is_nil(subscription) ->
        {:error, Error.new(:missing_subscription, "No active subscription found.")}

      is_nil(plan) or is_nil(provider_plan_id) ->
        {:error, Error.new(:unknown_plan, "Plan not found.")}

      upi_restricted?(subscription) ->
        {:error,
         Error.new(
           :upi_restriction,
           "UPI subscriptions can’t be updated in-place. Cancel at cycle end and pay again."
         )}

      true ->
        schedule_change_at = schedule_change_at(timing)

        provider_subscription =
          Queries.get_provider_subscription_by_provider_id(
            @provider,
            subscription.provider_subscription_id
          )

        case Razorpay.update_subscription(subscription.provider_subscription_id, %{
               plan_id: provider_plan_id,
               schedule_change_at: schedule_change_at
             }) do
          {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
            _ =
              Management.upsert_provider_subscription(
                provider_attrs_from_body(body, subscription, provider_subscription)
              )

            _ =
              Management.upsert_tenant_subscription(
                tenant_attrs_from_body(body, subscription, plan_code, schedule_change_at)
              )

            if schedule_change_at == "now" do
              _ = Tenants.update_billing_plan(tenant, plan_code)
            end

            {:ok, body}

          {:ok, %Req.Response{status: status, body: body}} ->
            Logger.warning("razorpay change plan failed status=#{status} body=#{inspect(body)}")
            {:error, Errors.from_provider(body, :provider_error, "Plan update failed.")}

          {:error, reason} ->
            Logger.warning("razorpay change plan error=#{inspect(reason)}")
            {:error, Error.new(:provider_error, "Plan update failed.")}
        end
    end
  end

  def cancel_scheduled_change(%Tenant{} = tenant) do
    with %TenantSubscription{} = subscription <- current_for_tenant(tenant.id),
         provider_subscription <-
           Queries.get_provider_subscription_by_provider_id(
             @provider,
             subscription.provider_subscription_id
           ),
         {:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
           Razorpay.cancel_scheduled_changes(subscription.provider_subscription_id) do
      _ =
        Management.upsert_provider_subscription(
          provider_attrs_from_body(body, subscription, provider_subscription)
        )

      attrs = tenant_attrs_from_body(body, subscription, subscription.plan_code, "now")
      _ = Management.upsert_tenant_subscription(%{attrs | pending_plan_code: nil})
      {:ok, body}
    else
      nil ->
        {:error, Error.new(:missing_subscription, "No active subscription found.")}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning(
          "razorpay cancel scheduled change failed status=#{status} body=#{inspect(body)}"
        )

        {:error,
         Errors.from_provider(body, :provider_error, "Unable to cancel scheduled change.")}

      {:error, reason} ->
        Logger.warning("razorpay cancel scheduled change error=#{inspect(reason)}")
        {:error, Error.new(:provider_error, "Unable to cancel scheduled change.")}
    end
  end

  def cancel(%Tenant{} = tenant, cancel_at_cycle_end \\ true) do
    with %TenantSubscription{} = subscription <- current_for_tenant(tenant.id),
         provider_subscription <-
           Queries.get_provider_subscription_by_provider_id(
             @provider,
             subscription.provider_subscription_id
           ),
         {:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
           Razorpay.cancel_subscription(
             subscription.provider_subscription_id,
             cancel_at_cycle_end
           ) do
      cancelled_at =
        Razorpay.timestamp_to_datetime(body["cancelled_at"]) ||
          if cancel_at_cycle_end do
            subscription.current_end_at || subscription.next_charge_at
          else
            DateTime.utc_now()
          end

      _ =
        Management.upsert_provider_subscription(
          body
          |> provider_attrs_from_body(subscription, provider_subscription)
          |> Map.put(:cancelled_at, cancelled_at)
        )

      _ =
        Management.upsert_tenant_subscription(
          body
          |> tenant_attrs_from_body(subscription)
          |> Map.put(:cancelled_at, cancelled_at)
        )

      {:ok, body}
    else
      nil ->
        {:error, Error.new(:missing_subscription, "No active subscription found.")}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("razorpay cancel failed status=#{status} body=#{inspect(body)}")
        {:error, Errors.from_provider(body, :provider_error, "Cancellation failed.")}

      {:error, reason} ->
        Logger.warning("razorpay cancel error=#{inspect(reason)}")
        {:error, Error.new(:provider_error, "Cancellation failed.")}
    end
  end

  def pay_again(%Tenant{} = tenant, plan_code) when is_binary(plan_code) do
    plan = Plans.get_by_code(plan_code)
    provider_plan_id = Plans.get_provider_plan_id(plan_code, @provider)
    subscription = current_for_tenant(tenant.id)
    upcoming = upcoming_for_tenant(tenant.id)

    cond do
      is_nil(plan) or is_nil(provider_plan_id) ->
        {:error, Error.new(:unknown_plan, "Plan not found.")}

      not is_nil(upcoming) ->
        {:ok, %{short_url: upcoming.short_url, subscription: upcoming}}

      is_nil(subscription) ->
        {:error, Error.new(:missing_subscription, "No active subscription found.")}

      upi_restricted?(subscription) and not cycle_ended?(subscription) ->
        {:error,
         Error.new(
           :upi_restriction,
           "UPI subscriptions require a new authorization after the current cycle."
         )}

      true ->
        start_at = future_start_at(subscription)
        total_count = Config.subscription_total_count()
        customer_notify = if Config.subscription_customer_notify(), do: 1, else: 0

        payload =
          %{
            plan_id: provider_plan_id,
            total_count: total_count,
            customer_notify: customer_notify,
            quantity: subscription.quantity || 1,
            notes: %{
              "plan_id" => plan.code,
              "plan_name" => plan.name,
              "source" => "swati"
            }
          }
          |> maybe_put_start_at(start_at)

        case Razorpay.create_subscription(payload) do
          {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
            short_url = body["short_url"]

            _ =
              Management.upsert_provider_subscription(
                provider_attrs_from_body(body, subscription, nil)
              )

            _ =
              Management.upsert_tenant_subscription(
                tenant_attrs_from_create(body, subscription, plan_code, short_url)
              )

            {:ok, %{short_url: short_url, subscription_id: body["id"]}}

          {:ok, %Req.Response{status: status, body: body}} ->
            Logger.warning("razorpay pay again failed status=#{status} body=#{inspect(body)}")
            {:error, Errors.from_provider(body, :provider_error, "Unable to prepare payment.")}

          {:error, reason} ->
            Logger.warning("razorpay pay again error=#{inspect(reason)}")
            {:error, Error.new(:provider_error, "Unable to prepare payment.")}
        end
    end
  end

  defp provider_attrs_from_body(body, subscription, provider_subscription) do
    %{
      provider: @provider,
      provider_subscription_id:
        body["id"] || (subscription && subscription.provider_subscription_id),
      provider_customer_id:
        body["customer_id"] ||
          (provider_subscription && provider_subscription.provider_customer_id),
      provider_plan_id:
        body["plan_id"] || (provider_subscription && provider_subscription.provider_plan_id),
      provider_status:
        body["status"] || (provider_subscription && provider_subscription.provider_status),
      quantity: body["quantity"] || (subscription && subscription.quantity) || 1,
      current_start_at: Razorpay.timestamp_to_datetime(body["current_start"]),
      current_end_at: Razorpay.timestamp_to_datetime(body["current_end"]),
      next_charge_at: Razorpay.timestamp_to_datetime(body["charge_at"]),
      cancelled_at: Razorpay.timestamp_to_datetime(body["cancelled_at"])
    }
  end

  defp tenant_attrs_from_body(body, subscription, plan_code \\ nil, schedule_change_at \\ "now") do
    pending_plan_code =
      if schedule_change_at == "cycle_end" do
        plan_code
      else
        nil
      end

    has_scheduled_changes =
      case body["has_scheduled_changes"] do
        nil -> schedule_change_at == "cycle_end"
        value -> value
      end

    %{
      tenant_id: subscription.tenant_id,
      provider: subscription.provider,
      provider_subscription_id: subscription.provider_subscription_id,
      plan_code: plan_code || subscription.plan_code,
      status: Razorpay.map_status(body["status"] || subscription.status),
      quantity: body["quantity"] || subscription.quantity,
      current_start_at:
        Razorpay.timestamp_to_datetime(body["current_start"]) || subscription.current_start_at,
      current_end_at:
        Razorpay.timestamp_to_datetime(body["current_end"]) || subscription.current_end_at,
      next_charge_at:
        Razorpay.timestamp_to_datetime(body["charge_at"]) || subscription.next_charge_at,
      cancelled_at:
        Razorpay.timestamp_to_datetime(body["cancelled_at"]) || subscription.cancelled_at,
      payment_method: subscription.payment_method,
      has_scheduled_changes: has_scheduled_changes,
      change_scheduled_at:
        Razorpay.timestamp_to_datetime(body["change_scheduled_at"]) ||
          subscription.change_scheduled_at,
      pending_plan_code: pending_plan_code,
      short_url: subscription.short_url
    }
  end

  defp tenant_attrs_from_create(body, subscription, plan_code, short_url) do
    %{
      tenant_id: subscription.tenant_id,
      provider: @provider,
      provider_subscription_id: body["id"],
      plan_code: plan_code,
      status: Razorpay.map_status(body["status"]),
      quantity: body["quantity"] || subscription.quantity,
      current_start_at:
        Razorpay.timestamp_to_datetime(body["start_at"] || body["current_start"]) ||
          subscription.current_end_at,
      current_end_at: Razorpay.timestamp_to_datetime(body["current_end"]),
      next_charge_at: Razorpay.timestamp_to_datetime(body["charge_at"]),
      payment_method: subscription.payment_method,
      short_url: short_url,
      metadata: %{
        "created_via" => "pay_again",
        "pay_again_for" => subscription.provider_subscription_id
      }
    }
  end

  defp maybe_put_start_at(payload, %DateTime{} = start_at) do
    Map.put(payload, :start_at, DateTime.to_unix(start_at))
  end

  defp maybe_put_start_at(payload, _start_at), do: payload

  defp schedule_change_at(:now), do: "now"
  defp schedule_change_at(:cycle_end), do: "cycle_end"
  defp schedule_change_at("cycle_end"), do: "cycle_end"
  defp schedule_change_at(_), do: "now"

  defp upi_restricted?(%TenantSubscription{} = subscription) do
    payment_method = subscription.payment_method |> to_string() |> String.downcase()
    payment_method == "upi"
  end

  defp future_start_at(%TenantSubscription{} = subscription) do
    now = DateTime.utc_now()

    case subscription.current_end_at do
      %DateTime{} = end_at ->
        if DateTime.compare(end_at, now) == :gt, do: end_at, else: now

      _ ->
        now
    end
  end

  defp cycle_ended?(%TenantSubscription{} = subscription) do
    now = DateTime.utc_now()

    case subscription.current_end_at do
      %DateTime{} = end_at -> DateTime.compare(end_at, now) != :gt
      _ -> false
    end
  end
end
