defmodule Swati.Tools.Commands do
  alias Swati.Repo
  alias Swati.Tools.Risk
  alias Swati.Tools.Tool

  def upsert_tool(tenant_id, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", tenant_id)
      |> Map.put_new("risk", Risk.default())

    case Repo.get_by(Tool, tenant_id: tenant_id, name: Map.get(attrs, "name")) do
      nil ->
        %Tool{}
        |> Tool.changeset(attrs)
        |> Repo.insert()

      tool ->
        tool
        |> Tool.changeset(attrs)
        |> Repo.update()
    end
  end

  def ensure_tools(tenant_id, names, origin) when is_list(names) do
    names =
      names
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    if names == [] do
      :ok
    else
      now = DateTime.utc_now()

      entries =
        Enum.map(names, fn name ->
          %{
            id: Ecto.UUID.generate(),
            tenant_id: tenant_id,
            name: name,
            origin: origin,
            status: "active",
            risk: Risk.default(),
            metadata: %{},
            inserted_at: now,
            updated_at: now
          }
        end)

      _ =
        Repo.insert_all(Tool, entries,
          on_conflict: :nothing,
          conflict_target: [:tenant_id, :name]
        )

      :ok
    end
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
