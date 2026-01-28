defmodule Swati.Billing.Queries do
  import Ecto.Query, warn: false

  alias Swati.Billing.{
    BillingCustomer,
    BillingCycle,
    BillingEvent,
    BillingNotification,
    Plan,
    PlanProvider,
    ProviderSubscription,
    TenantSubscription
  }

  alias Swati.Repo

  def get_plan_by_code(code) when is_binary(code) do
    Repo.get_by(Plan, code: code, status: "active")
  end

  def get_plan_by_provider_plan_id(provider, provider_plan_id)
      when is_binary(provider) and is_binary(provider_plan_id) do
    from(pp in PlanProvider,
      join: p in Plan,
      on: p.id == pp.plan_id,
      where:
        pp.provider == ^provider and pp.provider_plan_id == ^provider_plan_id and
          p.status == "active",
      select: p
    )
    |> Repo.one()
  end

  def get_provider_plan_id(plan_code, provider)
      when is_binary(plan_code) and is_binary(provider) do
    from(pp in PlanProvider,
      join: p in Plan,
      on: p.id == pp.plan_id,
      where: p.code == ^plan_code and pp.provider == ^provider,
      select: pp.provider_plan_id
    )
    |> Repo.one()
  end

  def list_active_plans do
    from(p in Plan, where: p.status == "active", order_by: [asc: p.name])
    |> Repo.all()
  end

  def get_billing_customer_by_provider_id(provider, provider_customer_id)
      when is_binary(provider) and is_binary(provider_customer_id) do
    Repo.get_by(BillingCustomer,
      provider: provider,
      provider_customer_id: provider_customer_id
    )
  end

  def get_billing_customer_for_tenant(tenant_id, provider)
      when is_binary(tenant_id) and is_binary(provider) do
    Repo.get_by(BillingCustomer, tenant_id: tenant_id, provider: provider)
  end

  def get_provider_subscription_by_provider_id(provider, provider_subscription_id)
      when is_binary(provider) and is_binary(provider_subscription_id) do
    Repo.get_by(ProviderSubscription,
      provider: provider,
      provider_subscription_id: provider_subscription_id
    )
  end

  def get_tenant_subscription_by_provider_id(provider, provider_subscription_id)
      when is_binary(provider) and is_binary(provider_subscription_id) do
    Repo.get_by(TenantSubscription,
      provider: provider,
      provider_subscription_id: provider_subscription_id
    )
  end

  def get_tenant_subscription!(subscription_id),
    do: Repo.get!(TenantSubscription, subscription_id)

  def get_tenant_subscription_for_tenant(tenant_id) when is_binary(tenant_id) do
    now = DateTime.utc_now()

    from(s in TenantSubscription,
      where: s.tenant_id == ^tenant_id,
      where: is_nil(s.current_start_at) or s.current_start_at <= ^now,
      order_by: [desc: s.current_start_at, desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_upcoming_subscription_for_tenant(tenant_id) when is_binary(tenant_id) do
    now = DateTime.utc_now()

    from(s in TenantSubscription,
      where: s.tenant_id == ^tenant_id,
      where: not is_nil(s.current_start_at) and s.current_start_at > ^now,
      order_by: [asc: s.current_start_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_billing_event!(event_id), do: Repo.get!(BillingEvent, event_id)

  def get_billing_event_by_provider_event_id(provider, provider_event_id)
      when is_binary(provider) and is_binary(provider_event_id) do
    Repo.get_by(BillingEvent, provider: provider, provider_event_id: provider_event_id)
  end

  def get_open_cycle(tenant_id) do
    from(c in BillingCycle,
      where: c.tenant_id == ^tenant_id and c.status == "open",
      order_by: [desc: c.start_at],
      limit: 1
    )
    |> Repo.one()
  end

  def get_cycle_by_range(tenant_subscription_id, start_at, end_at) do
    Repo.get_by(BillingCycle,
      tenant_subscription_id: tenant_subscription_id,
      start_at: start_at,
      end_at: end_at
    )
  end

  def list_open_cycles(tenant_subscription_id) do
    from(c in BillingCycle,
      where: c.tenant_subscription_id == ^tenant_subscription_id and c.status == "open"
    )
    |> Repo.all()
  end

  def get_notification(tenant_subscription_id, kind) when is_binary(kind) do
    Repo.get_by(BillingNotification,
      tenant_subscription_id: tenant_subscription_id,
      kind: kind
    )
  end
end
