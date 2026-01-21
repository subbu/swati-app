defmodule Swati.Tools.Queries do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Tools.Tool
  alias Swati.Tenancy

  def list_tools(tenant_id, filters \\ %{}) do
    Tool
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:origin, filters)
    |> maybe_filter(:status, filters)
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  def get_tool_by_name(tenant_id, name) when is_binary(name) do
    Tool
    |> Tenancy.scope(tenant_id)
    |> Repo.get_by(name: name)
  end

  def list_tools_by_names(tenant_id, names) when is_list(names) do
    Tool
    |> Tenancy.scope(tenant_id)
    |> where([t], t.name in ^names)
    |> Repo.all()
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end
end
