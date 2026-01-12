defmodule Swati.Webhooks.WebhookTag do
  use Swati.DbSchema

  schema "webhook_tags" do
    belongs_to :webhook, Swati.Webhooks.Webhook
    belongs_to :tag, Swati.Webhooks.Tag

    timestamps()
  end

  def changeset(webhook_tag, attrs) do
    webhook_tag
    |> cast(attrs, [:webhook_id, :tag_id])
    |> validate_required([:webhook_id, :tag_id])
    |> unique_constraint([:webhook_id, :tag_id])
  end
end
