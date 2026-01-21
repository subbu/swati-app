defmodule Swati.Channels.Endpoint do
  use Swati.DbSchema

  @statuses [:active, :inactive, :disabled]

  schema "endpoints" do
    field :address, :string
    field :display_name, :string
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :routing_policy, :map
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :channel, Swati.Channels.Channel
    belongs_to :phone_number, Swati.Telephony.PhoneNumber
    has_one :connection, Swati.Channels.ChannelConnection

    timestamps()
  end

  def changeset(endpoint, attrs) do
    endpoint
    |> cast(attrs, [
      :tenant_id,
      :channel_id,
      :address,
      :display_name,
      :status,
      :routing_policy,
      :metadata,
      :phone_number_id
    ])
    |> validate_required([:tenant_id, :channel_id, :address, :status])
    |> unique_constraint([:tenant_id, :channel_id, :address])
    |> unique_constraint(:phone_number_id)
  end
end
