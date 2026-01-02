defmodule Swati.Agents.AgentIntegration do
  use Swati.DbSchema

  schema "agent_integrations" do
    field :enabled, :boolean, default: true

    belongs_to :agent, Swati.Agents.Agent
    belongs_to :integration, Swati.Integrations.Integration

    timestamps()
  end

  def changeset(agent_integration, attrs) do
    agent_integration
    |> cast(attrs, [:agent_id, :integration_id, :enabled])
    |> validate_required([:agent_id, :integration_id, :enabled])
    |> unique_constraint([:agent_id, :integration_id])
  end
end
