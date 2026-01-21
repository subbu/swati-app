defmodule Swati.Tools do
  alias Swati.Tools.Commands
  alias Swati.Tools.Queries
  alias Swati.Tools.Risk

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

  def risk_map(tenant_id, names) when is_list(names) do
    names =
      names
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    tools =
      if names == [] do
        []
      else
        Queries.list_tools_by_names(tenant_id, names)
      end

    found =
      tools
      |> Map.new(fn tool -> {tool.name, tool.risk || Risk.default()} end)

    Enum.reduce(names, found, fn name, acc ->
      Map.put_new(acc, name, Risk.default())
    end)
  end
end
