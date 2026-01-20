defmodule SwatiWeb.CasesLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting

  def status_badge(status) do
    case to_string(status || "") do
      "new" -> %{label: "New", color: "info"}
      "triage" -> %{label: "Triage", color: "warning"}
      "in_progress" -> %{label: "In progress", color: "success"}
      "waiting_on_customer" -> %{label: "Waiting", color: "warning"}
      "resolved" -> %{label: "Resolved", color: "neutral"}
      "closed" -> %{label: "Closed", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def status_options do
    [
      {"All", ""},
      {"New", "new"},
      {"Triage", "triage"},
      {"In progress", "in_progress"},
      {"Waiting", "waiting_on_customer"},
      {"Resolved", "resolved"},
      {"Closed", "closed"}
    ]
  end

  def agent_options(agents) do
    [{"All", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
  end

  def priority_badge(priority) do
    case to_string(priority || "") do
      "low" -> %{label: "Low", color: "neutral"}
      "normal" -> %{label: "Normal", color: "info"}
      "high" -> %{label: "High", color: "warning"}
      "urgent" -> %{label: "Urgent", color: "danger"}
      _ -> %{label: "Normal", color: "info"}
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
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} hours ago"
      true -> "#{div(seconds, 86_400)} days ago"
    end
  end

  def customer_name(case_record) do
    case case_record.customer do
      nil -> "—"
      customer -> customer.name || customer.primary_email || customer.primary_phone || "Customer"
    end
  end

  def assigned_agent_name(case_record) do
    case case_record.assigned_agent do
      nil -> "Unassigned"
      agent -> agent.name
    end
  end

  def status_filter_label(filters) do
    case Map.get(filters, "status") do
      nil -> "Status"
      "" -> "Status"
      status -> status_badge(status).label
    end
  end

  def agent_filter_label(filters, agents) do
    case Map.get(filters, "assigned_agent_id") do
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

  def default_sort_direction("updated_at"), do: "desc"
  def default_sort_direction("priority"), do: "desc"
  def default_sort_direction(_column), do: "asc"
end
