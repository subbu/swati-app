defmodule Swati.Channels.Channel do
  use Swati.DbSchema

  @types [:voice, :email, :chat, :whatsapp, :custom]
  @statuses [:active, :inactive, :archived]

  schema "channels" do
    field :name, :string
    field :key, :string
    field :type, Ecto.Enum, values: @types
    field :status, Ecto.Enum, values: @statuses, default: :active
    field :capabilities, :map
    field :policy, :map, default: %{}
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant

    has_many :endpoints, Swati.Channels.Endpoint
    has_many :channel_integrations, Swati.Channels.ChannelIntegration
    has_many :channel_webhooks, Swati.Channels.ChannelWebhook
    has_many :connections, Swati.Channels.ChannelConnection

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:tenant_id, :name, :key, :type, :status, :capabilities, :policy, :metadata])
    |> validate_required([:tenant_id, :name, :key, :type, :status])
    |> unique_constraint([:tenant_id, :key])
  end
end
