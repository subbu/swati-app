defmodule Swati.Agents.AgentVersion do
  use Swati.DbSchema

  schema "agent_versions" do
    field :version, :integer
    field :config, :map
    field :published_at, :utc_datetime_usec

    belongs_to :agent, Swati.Agents.Agent

    timestamps()
  end

  def changeset(agent_version, attrs) do
    agent_version
    |> cast(attrs, [:agent_id, :version, :config, :published_at])
    |> validate_required([:agent_id, :version, :config])
    |> unique_constraint([:agent_id, :version])
  end
end
