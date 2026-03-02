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

    resolve_agent_name(owner_agent_id, agents)
  end

  def resolve_agent_name(nil, _agents), do: nil

  def resolve_agent_name(agent_id, agents) do
    case Enum.find(agents, &(to_string(&1.id) == to_string(agent_id))) do
      nil -> to_string(agent_id)
      agent -> agent.name
    end
  end

  # Keep backward compat alias
  def preview_owner_name(nil, _agents), do: "-"
  def preview_owner_name(agent_id, agents), do: resolve_agent_name(agent_id, agents) || "-"

  def format_datetime(nil), do: "-"

  def format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_datetime(_), do: "-"

  @doc """
  Relative time display: "just now", "2m ago", "1h ago", "yesterday", "Mar 1"
  """
  def relative_time(nil), do: "-"

  def relative_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      diff < 172_800 -> "yesterday"
      diff < 604_800 -> "#{div(diff, 86_400)}d ago"
      true -> Calendar.strftime(dt, "%b %-d")
    end
  end

  def relative_time(_), do: "-"

  def delivery_status_color(:processed), do: "success"
  def delivery_status_color(:received), do: "info"
  def delivery_status_color(:processing), do: "warning"
  def delivery_status_color(:duplicate), do: "neutral"
  def delivery_status_color(:failed), do: "danger"
  def delivery_status_color(:ignored), do: "neutral"
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
    get_in(delivery.route_details || %{}, ["owner_agent_id"])
  end

  def delivery_owner_name(delivery, agents) do
    resolve_agent_name(delivery_owner_agent_id(delivery), agents) || "-"
  end

  def delivery_route_reason(delivery) do
    get_in(delivery.route_details || %{}, ["route_reason"]) || "-"
  end

  def delivery_continuity(delivery) do
    case get_in(delivery.route_details || %{}, ["continuity", "hit"]) do
      true -> :hit
      false -> :miss
      _ -> nil
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

  @doc """
  Convert predicate map to a list of {type, icon, values} tuples for display as pills.
  """
  def format_predicates(nil), do: []
  def format_predicates(predicates) when not is_map(predicates), do: []

  def format_predicates(predicates) do
    []
    |> maybe_add_predicate(predicates, "to_addresses", "To")
    |> maybe_add_predicate(predicates, "to_domains", "Domain")
    |> maybe_add_predicate(predicates, "subject_contains", "Subject")
  end

  defp maybe_add_predicate(acc, predicates, key, label) do
    case Map.get(predicates, key) do
      nil -> acc
      "" -> acc
      [] -> acc
      values when is_list(values) ->
        acc ++ Enum.map(values, &{label, &1})

      value when is_binary(value) and value != "" ->
        acc ++ [{label, value}]

      _ ->
        acc
    end
  end

  @doc """
  Extract readable body text from a message payload.
  """
  def message_body(nil), do: nil

  def message_body(payload) when is_map(payload) do
    payload["text"] || payload[:text] || payload["body"] || payload[:body] ||
      extract_html_text(payload["html"] || payload[:html])
  end

  def message_body(_), do: nil

  defp extract_html_text(nil), do: nil

  defp extract_html_text(html) when is_binary(html) do
    html
    |> String.replace(~r/<br\s*\/?>/, "\n")
    |> String.replace(~r/<\/p>/, "\n\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/&nbsp;/, " ")
    |> String.replace(~r/&amp;/, "&")
    |> String.replace(~r/&lt;/, "<")
    |> String.replace(~r/&gt;/, ">")
    |> String.trim()
  end

  defp delivery_normalized(delivery) do
    delivery.normalized_payload || delivery.payload || %{}
  end

  def action_color("owner"), do: "info"
  def action_color("watcher"), do: "warning"
  def action_color("silent"), do: "neutral"
  def action_color(_), do: "neutral"
end
