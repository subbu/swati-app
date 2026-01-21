defmodule Swati.Channels.ChannelConnection do
  use Swati.DbSchema

  @providers [:gmail, :outlook, :imap, :custom]
  @statuses [:active, :error, :revoked, :disabled]

  schema "channel_connections" do
    field :provider, Ecto.Enum, values: @providers
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :last_synced_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :channel, Swati.Channels.Channel
    belongs_to :endpoint, Swati.Channels.Endpoint
    belongs_to :auth_secret, Swati.Integrations.Secret

    timestamps()
  end

  def changeset(connection, attrs) do
    connection
    |> cast(attrs, [
      :tenant_id,
      :channel_id,
      :endpoint_id,
      :provider,
      :status,
      :auth_secret_id,
      :last_synced_at,
      :metadata
    ])
    |> validate_required([:tenant_id, :channel_id, :endpoint_id, :provider, :status])
    |> unique_constraint(:endpoint_id)
  end
end
