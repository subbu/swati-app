defmodule Swati.Channels.ChannelWebhook do
  use Swati.DbSchema

  schema "channel_webhooks" do
    field :enabled, :boolean, default: true

    belongs_to :channel, Swati.Channels.Channel
    belongs_to :webhook, Swati.Webhooks.Webhook

    timestamps()
  end

  def changeset(channel_webhook, attrs) do
    channel_webhook
    |> cast(attrs, [:channel_id, :webhook_id, :enabled])
    |> validate_required([:channel_id, :webhook_id, :enabled])
    |> unique_constraint([:channel_id, :webhook_id])
  end
end
