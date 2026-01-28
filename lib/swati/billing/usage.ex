defmodule Swati.Billing.Usage do
  import Ecto.Query, warn: false

  alias Swati.Billing.{
    BillingCycle,
    Entitlements,
    Queries,
    TenantSubscription,
    UsageCounter,
    UsageEvent
  }

  alias Swati.Calls.Call
  alias Swati.Integrations
  alias Swati.Repo
  alias Swati.Telephony

  @metric_phone_numbers_current "phone_numbers_current"
  @metric_phone_numbers_peak "phone_numbers_peak"
  @metric_integrations_current "integrations_current"
  @metric_integrations_peak "integrations_peak"
  @metric_call_minutes_used "call_minutes_used"
  @metric_call_minutes_overage "call_minutes_overage"

  def current_cycle(tenant_id) do
    Queries.get_open_cycle(tenant_id)
  end

  def summary(tenant_id) do
    case current_cycle(tenant_id) do
      %BillingCycle{} = cycle ->
        counters =
          from(c in UsageCounter, where: c.cycle_id == ^cycle.id)
          |> Repo.all()
          |> Map.new(fn counter -> {counter.metric, counter.amount} end)

        %{cycle: cycle, counters: counters}

      _ ->
        %{cycle: nil, counters: %{}}
    end
  end

  def ensure_cycle(%TenantSubscription{} = subscription, start_at, end_at, entitlements) do
    with %DateTime{} <- start_at,
         %DateTime{} <- end_at do
      case Queries.get_cycle_by_range(subscription.id, start_at, end_at) do
        %BillingCycle{} = cycle ->
          {:ok, cycle}

        nil ->
          close_open_cycles(subscription.id)

          changeset =
            BillingCycle.changeset(%BillingCycle{}, %{
              tenant_subscription_id: subscription.id,
              tenant_id: subscription.tenant_id,
              start_at: start_at,
              end_at: end_at,
              status: "open",
              usage_summary: %{"entitlements" => entitlements}
            })

          Repo.insert(changeset)
      end
    else
      _ -> {:error, :missing_cycle_bounds}
    end
  end

  def ensure_cycle(_subscription, _start_at, _end_at, _entitlements), do: {:error, :missing_cycle}

  def refresh_phone_numbers(tenant_id) do
    with %BillingCycle{} = cycle <- current_cycle(tenant_id) do
      count = Telephony.count_phone_numbers(tenant_id)
      _ = set_counter(cycle, @metric_phone_numbers_current, count)
      _ = set_peak_counter(cycle, @metric_phone_numbers_peak, count)
      :ok
    else
      _ -> :ok
    end
  end

  def refresh_integrations(tenant_id) do
    with %BillingCycle{} = cycle <- current_cycle(tenant_id) do
      count = Integrations.count_integrations(tenant_id)
      _ = set_counter(cycle, @metric_integrations_current, count)
      _ = set_peak_counter(cycle, @metric_integrations_peak, count)
      :ok
    else
      _ -> :ok
    end
  end

  def record_call_minutes(%Call{} = call) do
    minutes = call_minutes(call)

    if minutes > 0 do
      with %BillingCycle{} = cycle <- current_cycle(call.tenant_id) do
        _ =
          %UsageEvent{}
          |> UsageEvent.changeset(%{
            tenant_id: call.tenant_id,
            cycle_id: cycle.id,
            metric: @metric_call_minutes_used,
            amount: minutes,
            source_type: "call",
            source_id: call.id,
            occurred_at: call.ended_at || DateTime.utc_now()
          })
          |> Repo.insert()

        used = increment_counter(cycle, @metric_call_minutes_used, minutes)

        entitlements =
          cycle.usage_summary
          |> Map.get("entitlements", %{})
          |> Entitlements.normalize_entitlements()

        included = Entitlements.included_call_minutes(entitlements) || 0
        overage = max(used - included, 0)
        _ = set_counter(cycle, @metric_call_minutes_overage, overage)
        :ok
      else
        _ -> :ok
      end
    else
      :ok
    end
  end

  defp call_minutes(%Call{duration_seconds: duration_seconds})
       when is_integer(duration_seconds) do
    if duration_seconds > 0 do
      div(duration_seconds + 59, 60)
    else
      0
    end
  end

  defp call_minutes(_), do: 0

  defp close_open_cycles(tenant_subscription_id) do
    from(c in BillingCycle,
      where: c.tenant_subscription_id == ^tenant_subscription_id and c.status == "open"
    )
    |> Repo.update_all(set: [status: "closed", updated_at: DateTime.utc_now()])
  end

  defp increment_counter(%BillingCycle{} = cycle, metric, amount) do
    {:ok, counter} =
      %UsageCounter{}
      |> UsageCounter.changeset(%{
        tenant_id: cycle.tenant_id,
        cycle_id: cycle.id,
        metric: metric,
        amount: amount
      })
      |> Repo.insert(
        on_conflict: [inc: [amount: amount]],
        conflict_target: [:cycle_id, :metric],
        returning: [:amount]
      )

    counter.amount || amount
  end

  defp set_counter(%BillingCycle{} = cycle, metric, amount) do
    %UsageCounter{}
    |> UsageCounter.changeset(%{
      tenant_id: cycle.tenant_id,
      cycle_id: cycle.id,
      metric: metric,
      amount: amount
    })
    |> Repo.insert(
      on_conflict: [set: [amount: amount]],
      conflict_target: [:cycle_id, :metric]
    )
  end

  defp set_peak_counter(%BillingCycle{} = cycle, metric, amount) do
    case Repo.get_by(UsageCounter, cycle_id: cycle.id, metric: metric) do
      %UsageCounter{amount: existing} when existing >= amount ->
        :ok

      %UsageCounter{} = counter ->
        counter
        |> UsageCounter.changeset(%{amount: amount})
        |> Repo.update()

      nil ->
        set_counter(cycle, metric, amount)
    end
  end
end
