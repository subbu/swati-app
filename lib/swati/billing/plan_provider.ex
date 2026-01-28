defmodule Swati.Billing.PlanProvider do
  use Swati.DbSchema

  schema "billing_plan_providers" do
    field :provider, :string
    field :provider_plan_id, :string

    belongs_to :plan, Swati.Billing.Plan

    timestamps()
  end

  def changeset(plan_provider, attrs) do
    plan_provider
    |> cast(attrs, [:plan_id, :provider, :provider_plan_id])
    |> validate_required([:plan_id, :provider, :provider_plan_id])
    |> unique_constraint([:plan_id, :provider])
    |> unique_constraint([:provider, :provider_plan_id])
  end
end
