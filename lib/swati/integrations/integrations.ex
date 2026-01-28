defmodule Swati.Integrations do
  alias Swati.Integrations.Integration
  alias Swati.Integrations.Management
  alias Swati.Integrations.MCP
  alias Swati.Integrations.Queries
  alias Swati.Integrations.Secrets

  def list_integrations(tenant_id) do
    Queries.list_integrations(tenant_id)
  end

  def count_integrations(tenant_id) do
    Queries.count_integrations(tenant_id)
  end

  def get_integration!(tenant_id, integration_id) do
    Queries.get_integration!(tenant_id, integration_id)
  end

  def list_integrations_for_agent(tenant_id, agent_id) do
    Queries.list_integrations_for_agent(tenant_id, agent_id)
  end

  def list_integrations_with_secrets(tenant_id, agent_id \\ nil) do
    Secrets.list_integrations_with_secrets(tenant_id, agent_id)
  end

  def create_integration(tenant_id, attrs, actor) do
    Management.create_integration(tenant_id, attrs, actor)
  end

  def update_integration(%Integration{} = integration, attrs, actor) do
    Management.update_integration(integration, attrs, actor)
  end

  def delete_integration(%Integration{} = integration, actor) do
    Management.delete_integration(integration, actor)
  end

  def test_integration(%Integration{} = integration) do
    MCP.test_integration(integration)
  end

  def fetch_tools(%Integration{} = integration) do
    MCP.fetch_tools(integration)
  end
end
