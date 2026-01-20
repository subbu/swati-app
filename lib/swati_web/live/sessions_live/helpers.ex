defmodule SwatiWeb.SessionsLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting

  def status_badge(status) do
    case to_string(status || "") do
      "open" -> %{label: "Open", color: "info"}
      "active" -> %{label: "Active", color: "success"}
      "waiting_on_customer" -> %{label: "Waiting", color: "warning"}
      "closed" -> %{label: "Closed", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def format_datetime(nil, _tenant), do: "—"

  def format_datetime(%DateTime{} = dt, tenant) do
    Formatting.datetime(dt, tenant)
  end

  def format_relative(nil, _tenant), do: "—"

  def format_relative(%DateTime{} = dt, _tenant) do
    seconds = max(DateTime.diff(DateTime.utc_now(), dt, :second), 0)

    cond do
      seconds < 60 ->
        "just now"

      seconds < 3600 ->
        minutes = div(seconds, 60)
        "#{minutes} min#{plural_suffix(minutes)} ago"

      seconds < 86_400 ->
        hours = div(seconds, 3600)
        "#{hours} hour#{plural_suffix(hours)} ago"

      seconds < 2_592_000 ->
        days = div(seconds, 86_400)
        "#{days} day#{plural_suffix(days)} ago"

      seconds < 31_536_000 ->
        months = div(seconds, 2_592_000)
        "#{months} month#{plural_suffix(months)} ago"

      true ->
        years = div(seconds, 31_536_000)
        "#{years} year#{plural_suffix(years)} ago"
    end
  end

  def session_label(session) do
    external = session.external_id
    if is_binary(external) and external != "", do: external, else: short_id(session.id)
  end

  def endpoint_address(session) do
    cond do
      session.endpoint && session.endpoint.address ->
        session.endpoint.address

      is_map(session.metadata) ->
        Map.get(session.metadata, "to_address") || Map.get(session.metadata, :to_address) || "—"

      true ->
        "—"
    end
  end

  def customer_address(session) do
    if is_map(session.metadata) do
      Map.get(session.metadata, "from_address") || Map.get(session.metadata, :from_address) || "—"
    else
      "—"
    end
  end

  def agent_name(session) do
    case session.agent do
      nil -> "Unassigned"
      agent -> agent.name
    end
  end

  defp short_id(nil), do: "—"

  defp short_id(id) do
    id
    |> to_string()
    |> String.slice(0, 8)
  end

  defp plural_suffix(value) when value == 1, do: ""
  defp plural_suffix(_value), do: "s"
end
