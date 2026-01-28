defmodule Swati.Billing.Plan do
  use Swati.DbSchema

  @statuses ["active", "archived"]

  schema "billing_plans" do
    field :code, :string
    field :name, :string
    field :amount, :integer
    field :currency, :string
    field :entitlements, :map, default: %{}
    field :status, :string, default: "active"

    timestamps()
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:code, :name, :amount, :currency, :entitlements, :status])
    |> validate_required([
      :code,
      :name,
      :amount,
      :currency,
      :entitlements,
      :status
    ])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:code)
  end
end
