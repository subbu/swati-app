defmodule Swati.Billing.UsageEvent do
  use Swati.DbSchema

  schema "billing_usage_events" do
    field :metric, :string
    field :amount, :integer
    field :source_type, :string
    field :source_id, :binary_id
    field :occurred_at, :utc_datetime_usec

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :cycle, Swati.Billing.BillingCycle

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :tenant_id,
      :cycle_id,
      :metric,
      :amount,
      :source_type,
      :source_id,
      :occurred_at
    ])
    |> validate_required([:tenant_id, :cycle_id, :metric, :amount, :occurred_at])
  end
end
