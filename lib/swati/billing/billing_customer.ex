defmodule Swati.Billing.BillingCustomer do
  use Swati.DbSchema

  schema "billing_customers" do
    field :provider, :string
    field :provider_customer_id, :string
    field :email, :string
    field :contact, :string
    field :metadata, :map, default: %{}

    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(customer, attrs) do
    customer
    |> cast(attrs, [:tenant_id, :provider, :provider_customer_id, :email, :contact, :metadata])
    |> validate_required([:tenant_id, :provider])
    |> unique_constraint([:tenant_id, :provider])
    |> unique_constraint([:provider, :provider_customer_id])
  end
end
