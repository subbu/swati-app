defmodule Swati.Agents.AgentChannel do
  use Swati.DbSchema

  schema "agent_channels" do
    field :enabled, :boolean, default: true
    field :scope, :map, default: %{"mode" => "all"}

    belongs_to :agent, Swati.Agents.Agent
    belongs_to :channel, Swati.Channels.Channel

    timestamps()
  end

  def changeset(agent_channel, attrs) do
    agent_channel
    |> cast(attrs, [:agent_id, :channel_id, :enabled, :scope])
    |> validate_required([:agent_id, :channel_id, :enabled])
    |> unique_constraint([:agent_id, :channel_id])
  end
end
