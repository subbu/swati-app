defmodule SwatiWeb.InboundEmailLive.Helpers do
  def agent_options(agents) do
    [{"Select", ""}] ++ Enum.map(agents, &{&1.name, &1.id})
  end

  def binding_owner_name(binding, agents) do
    owner_agent_id =
      binding.routing_policy
      |> case do
        map when is_map(map) ->
          Map.get(map, "default_agent_id") || Map.get(map, :default_agent_id)

        _ ->
          nil
      end

    preview_owner_name(owner_agent_id, agents)
  end

  def preview_owner_name(nil, _agents), do: "-"

  def preview_owner_name(agent_id, agents) do
    case Enum.find(agents, &(to_string(&1.id) == to_string(agent_id))) do
      nil -> agent_id
      agent -> agent.name
    end
  end

  def format_datetime(nil), do: "-"

  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_datetime(_), do: "-"

  def delivery_status_color(:processed), do: "success"
  def delivery_status_color(:received), do: "info"
  def delivery_status_color(:processing), do: "warning"
  def delivery_status_color(:duplicate), do: "neutral"
  def delivery_status_color(:failed), do: "danger"
  def delivery_status_color(_), do: "neutral"

  def delivery_from(delivery) do
    normalized = delivery_normalized(delivery)
    Map.get(normalized, "from") || get_in(delivery.payload || %{}, ["data", "from"]) || "-"
  end

  def delivery_to(delivery) do
    normalized = delivery_normalized(delivery)

    (Map.get(normalized, "to") || get_in(delivery.payload || %{}, ["data", "to"]) || [])
    |> List.wrap()
    |> Enum.join(", ")
  end

  def delivery_subject(delivery) do
    normalized = delivery_normalized(delivery)
    Map.get(normalized, "subject") || get_in(delivery.payload || %{}, ["data", "subject"]) || "-"
  end

  def delivery_owner_agent_id(delivery) do
    get_in(delivery.route_details || %{}, ["owner_agent_id"]) || "-"
  end

  def delivery_route_reason(delivery) do
    get_in(delivery.route_details || %{}, ["route_reason"]) || "-"
  end

  def delivery_continuity(delivery) do
    case get_in(delivery.route_details || %{}, ["continuity", "hit"]) do
      true -> "hit"
      false -> "miss"
      _ -> "-"
    end
  end

  def delivery_session_id(delivery) do
    get_in(delivery.runtime_result || %{}, ["session_id"])
  end

  def delivery_case_id(delivery) do
    get_in(delivery.runtime_result || %{}, ["case_id"])
  end

  def delivery_replayable?(delivery) do
    delivery.status in [:failed, :processed, :duplicate, :ignored]
  end

  defp delivery_normalized(delivery) do
    delivery.normalized_payload || delivery.payload || %{}
  end
end
