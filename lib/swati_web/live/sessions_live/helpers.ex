defmodule SwatiWeb.SessionsLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting
  alias Swati.Sessions

  def status_badge(status) do
    case to_string(status || "") do
      "open" -> %{label: "Open", color: "info"}
      "active" -> %{label: "Active", color: "success"}
      "waiting_on_customer" -> %{label: "Waiting", color: "warning"}
      "closed" -> %{label: "Closed", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def approval_status_badge(status) do
    case to_string(status || "") do
      "pending" -> %{label: "Pending", color: "warning"}
      "approved" -> %{label: "Approved", color: "success"}
      "rejected" -> %{label: "Rejected", color: "danger"}
      "cancelled" -> %{label: "Cancelled", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def handoff_status_badge(status) do
    case to_string(status || "") do
      "requested" -> %{label: "Requested", color: "warning"}
      "accepted" -> %{label: "Accepted", color: "success"}
      "declined" -> %{label: "Declined", color: "danger"}
      "ended" -> %{label: "Ended", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def status_options do
    [
      {"All", ""},
      {"Open", "open"},
      {"Active", "active"},
      {"Waiting", "waiting_on_customer"},
      {"Closed", "closed"}
    ]
  end

  def agent_options(agents) do
    [{"All", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
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

  def direction_display(session) do
    case to_string(session.direction || "") do
      "inbound" ->
        %{label: "Inbound", icon_name: "hero-arrow-down-left", icon_class: "text-emerald-500"}

      "outbound" ->
        %{label: "Outbound", icon_name: "hero-arrow-up-right", icon_class: "text-sky-500"}

      _ ->
        %{label: "Unknown", icon_name: "hero-minus-small", icon_class: "text-zinc-400"}
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
    address =
      if is_map(session.metadata) do
        Map.get(session.metadata, "from_address") || Map.get(session.metadata, :from_address)
      end

    address || "—"
  end

  def customer_name(session) do
    case session.customer do
      nil -> "—"
      customer -> customer.name || customer.primary_email || customer.primary_phone || "Customer"
    end
  end

  def agent_name(session) do
    case session.agent do
      nil -> "Unassigned"
      agent -> agent.name
    end
  end

  def priority_label(priority) do
    case to_string(priority || "") do
      "low" -> "Low"
      "normal" -> "Normal"
      "high" -> "High"
      "urgent" -> "Urgent"
      _ -> "Normal"
    end
  end

  def case_category(case_record) do
    category = Map.get(case_record || %{}, :category)
    if is_binary(category) and category != "", do: category, else: "General"
  end

  defp short_id(nil), do: "—"

  defp short_id(id) do
    id
    |> to_string()
    |> String.slice(0, 8)
  end

  defp plural_suffix(value) when value == 1, do: ""
  defp plural_suffix(_value), do: "s"

  def status_filter_label(filters) do
    case Map.get(filters, "status") do
      nil -> "Status"
      "" -> "Status"
      status -> status_badge(status).label
    end
  end

  def agent_filter_label(filters, agents) do
    case Map.get(filters, "agent_id") do
      nil ->
        "Agent"

      "" ->
        "Agent"

      agent_id ->
        case Enum.find(agents, &(to_string(&1.id) == to_string(agent_id))) do
          nil -> "Agent"
          agent -> agent.name
        end
    end
  end

  def sort_button_class(column, %{column: column}),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground"

  def sort_button_class(_column, _sort),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground-soft"

  def sort_icon_class(column, %{column: column}), do: "text-foreground"
  def sort_icon_class(_column, _sort), do: "text-foreground-softest"

  attr :column, :string, required: true
  attr :sort, :map, required: true

  def sort_icon(assigns) do
    ~H"""
    <%= if @sort.column == @column do %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        class={["size-4", sort_icon_class(@column, @sort)]}
      >
        <path
          fill="currentColor"
          d={if @sort.direction == "asc", do: "M11 7H5l3-4z", else: "M5 9h6l-3 4z"}
        />
      </svg>
    <% else %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        class={["size-4", sort_icon_class(@column, @sort)]}
      >
        <path fill="currentColor" d="M11 7H5l3-4z" />
        <path fill="currentColor" d="M5 9h6l-3 4z" />
      </svg>
    <% end %>
    """
  end

  def next_sort(%{column: column, direction: direction}, column),
    do: %{column: column, direction: toggle_sort_direction(direction)}

  def next_sort(_sort, column),
    do: %{column: column, direction: default_sort_direction(column)}

  def toggle_sort_direction("asc"), do: "desc"
  def toggle_sort_direction(_direction), do: "asc"

  def default_sort_direction("started_at"), do: "desc"
  def default_sort_direction("last_event_at"), do: "desc"
  def default_sort_direction(_column), do: "asc"

  def parse_id(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  def parse_id(id), do: id

  def transcript_download_url(session) do
    artifact_url(artifact_payload(session, "transcript"), [
      {"text_url", :text_url},
      {"jsonl_url", :jsonl_url}
    ])
  end

  def recording_download_url(session) do
    artifact_url(artifact_payload(session, "recording"), [
      {"stereo_url", :stereo_url},
      {"caller_url", :caller_url},
      {"agent_url", :agent_url}
    ])
  end

  def build_call_like(session) do
    recording = Sessions.get_session_recording(session.id) || %{}
    transcript = Sessions.get_session_transcript(session.id) || %{}
    metadata = session.metadata || %{}

    %{
      id: session.id,
      status: session.status,
      started_at: session.started_at,
      ended_at: session.ended_at,
      duration_seconds: session_duration_seconds(session),
      recording: recording,
      transcript: transcript,
      from_number: Map.get(metadata, "from_address") || Map.get(metadata, :from_address),
      to_number: Map.get(metadata, "to_address") || Map.get(metadata, :to_address),
      agent: session.agent,
      events: session.events
    }
  end

  def session_duration_seconds(%{duration_seconds: duration}) when is_integer(duration),
    do: duration

  def session_duration_seconds(%{
        started_at: %DateTime{} = started_at,
        ended_at: %DateTime{} = ended_at
      }) do
    max(DateTime.diff(ended_at, started_at, :second), 0)
  end

  def session_duration_seconds(%{started_at: %DateTime{} = started_at, status: status})
      when status in [:open, :active, "open", "active"] do
    max(DateTime.diff(DateTime.utc_now(), started_at, :second), 0)
  end

  def session_duration_seconds(_session), do: nil

  defp artifact_payload(session, kind) do
    artifacts = session.artifacts || []

    case Enum.find(artifacts, &(&1.kind == kind)) do
      nil -> nil
      artifact -> artifact.payload
    end
  end

  defp artifact_url(nil, _keys), do: nil

  defp artifact_url(map, keys) when is_map(map) do
    Enum.find_value(keys, fn {string_key, atom_key} ->
      Map.get(map, string_key) || Map.get(map, atom_key)
    end)
  end

  defp artifact_url(_value, _keys), do: nil
end
