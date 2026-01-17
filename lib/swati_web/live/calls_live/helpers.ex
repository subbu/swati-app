defmodule SwatiWeb.CallsLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting

  def status_options do
    [
      {"All", ""},
      {"Started", "started"},
      {"In progress", "in_progress"},
      {"Ended", "ended"},
      {"Failed", "failed"},
      {"Cancelled", "cancelled"},
      {"Error", "error"}
    ]
  end

  def agent_options(agents) do
    [{"All", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
  end

  def format_datetime(nil, _tenant), do: "—"

  def format_datetime(%DateTime{} = dt, tenant) do
    Formatting.datetime(dt, tenant)
  end

  def format_phone(nil, _tenant), do: "—"
  def format_phone("", _tenant), do: "—"

  def format_phone(number, tenant) do
    Formatting.phone(number, tenant) || "—"
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

  def format_duration(call) do
    seconds = call_duration_seconds(call)

    cond do
      is_nil(seconds) -> "—"
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m #{rem(seconds, 60)}s"
    end
  end

  def call_duration_seconds(%{duration_seconds: duration}) when is_integer(duration),
    do: duration

  def call_duration_seconds(%{
        started_at: %DateTime{} = started_at,
        ended_at: %DateTime{} = ended_at
      }) do
    max(DateTime.diff(ended_at, started_at, :second), 0)
  end

  def call_duration_seconds(%{started_at: %DateTime{} = started_at, status: status})
      when status in [:started, :in_progress, "started", "in_progress"] do
    max(DateTime.diff(DateTime.utc_now(), started_at, :second), 0)
  end

  def call_duration_seconds(_call), do: nil

  def duration_bar_class(status) do
    case status do
      :ended -> "bg-emerald-500"
      "ended" -> "bg-emerald-500"
      :in_progress -> "bg-sky-500"
      "in_progress" -> "bg-sky-500"
      :started -> "bg-sky-400"
      "started" -> "bg-sky-400"
      :failed -> "bg-rose-500"
      "failed" -> "bg-rose-500"
      :error -> "bg-rose-500"
      "error" -> "bg-rose-500"
      :cancelled -> "bg-zinc-400"
      "cancelled" -> "bg-zinc-400"
      _ -> "bg-foreground/40"
    end
  end

  def direction_display(call, phone_number_e164s) do
    case call_direction(call, phone_number_e164s) do
      :incoming ->
        %{label: "Incoming", icon_name: "hero-arrow-down-left", icon_class: "text-emerald-500"}

      :outgoing ->
        %{label: "Outgoing", icon_name: "hero-arrow-up-right", icon_class: "text-sky-500"}

      _ ->
        %{label: "Unknown", icon_name: "hero-minus-small", icon_class: "text-zinc-400"}
    end
  end

  def call_direction(%{to_number: to_number, from_number: from_number}, phone_number_e164s) do
    cond do
      is_nil(to_number) or is_nil(from_number) -> :unknown
      MapSet.member?(phone_number_e164s, to_number) -> :incoming
      MapSet.member?(phone_number_e164s, from_number) -> :outgoing
      true -> :unknown
    end
  end

  def agent_display(agent_id, agents) do
    case Enum.find(agents, &(&1.id == agent_id)) do
      nil ->
        %{name: "Unassigned", initial: "—", color: "bg-zinc-200/70 text-zinc-600"}

      agent ->
        %{name: agent.name, initial: String.first(agent.name), color: avatar_color(agent.name)}
    end
  end

  def agent_avatar_url(avatars_by_agent, agent_id, agent_name) do
    case Map.get(avatars_by_agent, agent_id) do
      %{status: :ready, output_url: url} when is_binary(url) ->
        url

      _ ->
        name =
          if is_binary(agent_name) and agent_name != "" do
            agent_name
          else
            "Agent"
          end

        "https://ui-avatars.com/api/?name=#{URI.encode_www_form(name)}"
    end
  end

  def avatar_color(name) do
    colors = [
      "bg-red-200/60 text-red-900",
      "bg-blue-200/60 text-blue-900",
      "bg-green-200/60 text-green-900",
      "bg-yellow-200/60 text-yellow-900",
      "bg-purple-200/60 text-purple-900",
      "bg-pink-200/60 text-pink-900",
      "bg-indigo-200/60 text-indigo-900",
      "bg-teal-200/60 text-teal-900"
    ]

    index = :erlang.phash2(name) |> rem(length(colors))
    Enum.at(colors, index)
  end

  def status_filter_label(filters) do
    case Map.get(filters, "status") do
      nil -> "Status"
      "" -> "Status"
      status -> status_display(status).label
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

  defp plural_suffix(value) when value == 1, do: ""
  defp plural_suffix(_value), do: "s"

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
  def default_sort_direction("duration_seconds"), do: "desc"
  def default_sort_direction(_column), do: "asc"

  def parse_id(id) when is_integer(id), do: id

  def parse_id(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  def parse_id(_id), do: nil

  def status_display(status) do
    case status do
      :ended ->
        %{label: "Ended", icon_name: "hero-check-circle", icon_class: "text-emerald-500"}

      "ended" ->
        %{label: "Ended", icon_name: "hero-check-circle", icon_class: "text-emerald-500"}

      :failed ->
        %{label: "Failed", icon_name: "hero-x-circle", icon_class: "text-rose-500"}

      "failed" ->
        %{label: "Failed", icon_name: "hero-x-circle", icon_class: "text-rose-500"}

      :error ->
        %{label: "Error", icon_name: "hero-exclamation-triangle", icon_class: "text-amber-500"}

      "error" ->
        %{label: "Error", icon_name: "hero-exclamation-triangle", icon_class: "text-amber-500"}

      :in_progress ->
        %{label: "In progress", icon_name: "hero-arrow-path", icon_class: "text-blue-500"}

      "in_progress" ->
        %{label: "In progress", icon_name: "hero-arrow-path", icon_class: "text-blue-500"}

      :cancelled ->
        %{label: "Cancelled", icon_name: "hero-signal-slash", icon_class: "text-zinc-500"}

      "cancelled" ->
        %{label: "Cancelled", icon_name: "hero-signal-slash", icon_class: "text-zinc-500"}

      :started ->
        %{label: "Started", icon_name: "hero-play-circle", icon_class: "text-foreground-softer"}

      "started" ->
        %{label: "Started", icon_name: "hero-play-circle", icon_class: "text-foreground-softer"}

      _ ->
        %{
          label: "Unknown",
          icon_name: "hero-question-mark-circle",
          icon_class: "text-foreground-softer"
        }
    end
  end
end
