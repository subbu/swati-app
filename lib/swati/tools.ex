defmodule Swati.Tools do
  alias Swati.Tools.Commands
  alias Swati.Tools.Queries

  def list_tools(tenant_id, filters \\ %{}) do
    Queries.list_tools(tenant_id, filters)
  end

  def get_tool_by_name(tenant_id, name) do
    Queries.get_tool_by_name(tenant_id, name)
  end

  def upsert_tool(tenant_id, attrs) do
    Commands.upsert_tool(tenant_id, attrs)
  end

  def ensure_tools(tenant_id, names, origin) do
    Commands.ensure_tools(tenant_id, names, origin)
  end
end
