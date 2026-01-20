defmodule Swati.Customers.CustomerIdentity do
  use Swati.DbSchema

  @kinds [:phone, :email, :handle, :external]

  schema "customer_identities" do
    field :kind, Ecto.Enum, values: @kinds
    field :external_id, :string
    field :address, :string
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :customer, Swati.Customers.Customer
    belongs_to :channel, Swati.Channels.Channel

    timestamps()
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [
      :tenant_id,
      :customer_id,
      :channel_id,
      :kind,
      :external_id,
      :address,
      :metadata
    ])
    |> validate_required([:tenant_id, :customer_id, :channel_id, :kind])
    |> unique_constraint([:tenant_id, :channel_id, :external_id])
  end
end
