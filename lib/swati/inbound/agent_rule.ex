defmodule Swati.Inbound.AgentRule do
  use Swati.DbSchema

  @actions [:owner, :watcher, :silent]

  schema "agent_inbound_rules" do
    field :name, :string
    field :enabled, :boolean, default: true
    field :priority, :integer, default: 100
    field :action, Ecto.Enum, values: @actions, default: :owner
    field :predicates, :map, default: %{}
    field :defaults, :map
    field :metadata, :map

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :agent, Swati.Agents.Agent

    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [
      :tenant_id,
      :agent_id,
      :name,
      :enabled,
      :priority,
      :action,
      :predicates,
      :defaults,
      :metadata
    ])
    |> validate_required([:tenant_id, :agent_id, :name, :enabled, :priority, :action])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000)
    |> unique_constraint(:name, name: :agent_inbound_rules_tenant_id_agent_id_name_index)
  end
end
