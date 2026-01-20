defmodule Swati.Channels.ChannelIntegration do
  use Swati.DbSchema

  schema "channel_integrations" do
    field :enabled, :boolean, default: true

    belongs_to :channel, Swati.Channels.Channel
    belongs_to :integration, Swati.Integrations.Integration

    timestamps()
  end

  def changeset(channel_integration, attrs) do
    channel_integration
    |> cast(attrs, [:channel_id, :integration_id, :enabled])
    |> validate_required([:channel_id, :integration_id, :enabled])
    |> unique_constraint([:channel_id, :integration_id])
  end
end
