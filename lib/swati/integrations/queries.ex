defmodule Swati.Integrations.Queries do
  import Ecto.Query, warn: false

  alias Swati.Agents.AgentIntegration
  alias Swati.Integrations.Integration
  alias Swati.Repo
  alias Swati.Tenancy

  def list_integrations(tenant_id) do
    Integration
    |> Tenancy.scope(tenant_id)
    |> Repo.all()
  end

  def get_integration!(tenant_id, integration_id) do
    Integration
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(integration_id)
  end

  def list_integrations_for_agent(tenant_id, agent_id) do
    from(i in Integration,
      left_join: ai in AgentIntegration,
      on: ai.integration_id == i.id and ai.agent_id == ^agent_id,
      where: i.tenant_id == ^tenant_id,
      where: i.status == :active,
      where: is_nil(ai.id) or ai.enabled == true,
      order_by: [asc: i.name]
    )
    |> Repo.all()
  end
end
