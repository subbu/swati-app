defmodule Swati.Billing.BillingCycle do
  use Swati.DbSchema

  @statuses ["open", "closed"]

  schema "billing_cycles" do
    field :start_at, :utc_datetime_usec
    field :end_at, :utc_datetime_usec
    field :status, :string, default: "open"
    field :usage_summary, :map, default: %{}

    belongs_to :tenant_subscription, Swati.Billing.TenantSubscription
    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(cycle, attrs) do
    cycle
    |> cast(attrs, [
      :tenant_subscription_id,
      :tenant_id,
      :start_at,
      :end_at,
      :status,
      :usage_summary
    ])
    |> validate_required([:tenant_subscription_id, :tenant_id, :start_at, :end_at, :status])
    |> validate_inclusion(:status, @statuses)
  end
end
