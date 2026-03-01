defmodule Swati.Inbound.Connector do
  use Swati.DbSchema

  @providers [:resend]
  @statuses [:active, :disabled]

  schema "inbound_connectors" do
    field :name, :string
    field :provider, Ecto.Enum, values: @providers
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :endpoint_token, :string
    field :default_channel_key, :string, default: "email"
    field :default_endpoint_address, :string
    field :routing_mode, :string, default: "continuity_first"
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :signing_secret, Swati.Integrations.Secret
    belongs_to :default_agent, Swati.Agents.Agent

    has_many :deliveries, Swati.Inbound.Delivery

    timestamps()
  end

  def changeset(connector, attrs) do
    connector
    |> cast(attrs, [
      :tenant_id,
      :name,
      :provider,
      :status,
      :endpoint_token,
      :signing_secret_id,
      :default_channel_key,
      :default_endpoint_address,
      :default_agent_id,
      :routing_mode,
      :metadata
    ])
    |> validate_required([
      :tenant_id,
      :name,
      :provider,
      :status,
      :endpoint_token,
      :default_channel_key,
      :routing_mode
    ])
    |> validate_length(:name, min: 2, max: 120)
    |> foreign_key_constraint(:signing_secret_id,
      name: :inbound_connectors_signing_secret_id_fkey
    )
    |> foreign_key_constraint(:default_agent_id, name: :inbound_connectors_default_agent_id_fkey)
    |> unique_constraint(:endpoint_token)
    |> unique_constraint(:name, name: :inbound_connectors_tenant_id_name_index)
  end
end
