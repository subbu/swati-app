defmodule Swati.Agents.AgentWebhook do
  use Swati.DbSchema

  schema "agent_webhooks" do
    field :enabled, :boolean, default: true

    belongs_to :agent, Swati.Agents.Agent
    belongs_to :webhook, Swati.Webhooks.Webhook

    timestamps()
  end

  def changeset(agent_webhook, attrs) do
    agent_webhook
    |> cast(attrs, [:agent_id, :webhook_id, :enabled])
    |> validate_required([:agent_id, :webhook_id, :enabled])
    |> unique_constraint([:agent_id, :webhook_id])
  end
end
