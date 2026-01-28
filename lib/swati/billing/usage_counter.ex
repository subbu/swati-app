defmodule Swati.Billing.UsageCounter do
  use Swati.DbSchema

  schema "billing_usage_counters" do
    field :metric, :string
    field :amount, :integer, default: 0

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :cycle, Swati.Billing.BillingCycle

    timestamps(updated_at: false)
  end

  def changeset(counter, attrs) do
    counter
    |> cast(attrs, [:tenant_id, :cycle_id, :metric, :amount])
    |> validate_required([:tenant_id, :cycle_id, :metric, :amount])
    |> unique_constraint([:cycle_id, :metric])
  end
end
