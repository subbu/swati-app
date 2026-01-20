defmodule Swati.Preferences.Definitions do
  @moduledoc false

  @calls_index_key "calls.index.view_state"
  @calls_index_columns ~w(direction started_at from_number duration_seconds status agent_id)
  @calls_index_statuses ~w(started in_progress ended failed cancelled error)
  @calls_index_sort_columns ~w(started_at from_number duration_seconds status agent_id)
  @sessions_index_key "sessions.index.view_state"
  @sessions_index_columns ~w(session customer channel endpoint direction status last_event_at agent)
  @sessions_index_statuses ~w(open active waiting_on_customer closed)
  @sessions_index_sort_columns ~w(started_at last_event_at status direction)
  @cases_index_key "cases.index.view_state"
  @cases_index_columns ~w(case status priority customer assigned_agent updated_at)
  @cases_index_statuses ~w(new triage in_progress waiting_on_customer resolved closed)
  @cases_index_sort_columns ~w(updated_at priority status)

  def calls_index_key, do: @calls_index_key
  def calls_index_columns, do: @calls_index_columns
  def calls_index_defaults, do: default(@calls_index_key)
  def sessions_index_key, do: @sessions_index_key
  def sessions_index_columns, do: @sessions_index_columns
  def sessions_index_defaults, do: default(@sessions_index_key)
  def cases_index_key, do: @cases_index_key
  def cases_index_columns, do: @cases_index_columns
  def cases_index_defaults, do: default(@cases_index_key)

  def schema_version(@calls_index_key), do: 1
  def schema_version(@sessions_index_key), do: 1
  def schema_version(@cases_index_key), do: 1

  def schema_version(key) do
    raise ArgumentError, "unknown preference key: #{inspect(key)}"
  end

  def default(@calls_index_key) do
    %{
      "columns" => @calls_index_columns,
      "filters" => default_filters(),
      "sort" => default_sort()
    }
  end

  def default(@sessions_index_key) do
    %{
      "columns" => @sessions_index_columns,
      "filters" => default_sessions_filters(),
      "sort" => default_sessions_sort()
    }
  end

  def default(@cases_index_key) do
    %{
      "columns" => @cases_index_columns,
      "filters" => default_cases_filters(),
      "sort" => default_cases_sort()
    }
  end

  def default(key) do
    raise ArgumentError, "unknown preference key: #{inspect(key)}"
  end

  def normalize(@calls_index_key, value) do
    value = normalize_map(value)

    %{
      "columns" => normalize_columns(Map.get(value, "columns")),
      "filters" => normalize_filters(Map.get(value, "filters")),
      "sort" => normalize_sort(Map.get(value, "sort"))
    }
  end

  def normalize(@sessions_index_key, value) do
    value = normalize_map(value)

    %{
      "columns" => normalize_sessions_columns(Map.get(value, "columns")),
      "filters" => normalize_sessions_filters(Map.get(value, "filters")),
      "sort" => normalize_sessions_sort(Map.get(value, "sort"))
    }
  end

  def normalize(@cases_index_key, value) do
    value = normalize_map(value)

    %{
      "columns" => normalize_cases_columns(Map.get(value, "columns")),
      "filters" => normalize_cases_filters(Map.get(value, "filters")),
      "sort" => normalize_cases_sort(Map.get(value, "sort"))
    }
  end

  def normalize(key, _value) do
    raise ArgumentError, "unknown preference key: #{inspect(key)}"
  end

  def merge(@calls_index_key, existing, updates) do
    existing = normalize(@calls_index_key, existing)
    updates = normalize_map(updates)
    merged = deep_merge(existing, updates)

    normalize(@calls_index_key, merged)
  end

  def merge(@sessions_index_key, existing, updates) do
    existing = normalize(@sessions_index_key, existing)
    updates = normalize_map(updates)
    merged = deep_merge(existing, updates)

    normalize(@sessions_index_key, merged)
  end

  def merge(@cases_index_key, existing, updates) do
    existing = normalize(@cases_index_key, existing)
    updates = normalize_map(updates)
    merged = deep_merge(existing, updates)

    normalize(@cases_index_key, merged)
  end

  def merge(key, _existing, _updates) do
    raise ArgumentError, "unknown preference key: #{inspect(key)}"
  end

  defp default_filters do
    %{"status" => "", "agent_id" => ""}
  end

  defp default_sort do
    %{"column" => "started_at", "direction" => "desc"}
  end

  defp default_sessions_filters do
    %{"status" => "", "agent_id" => "", "query" => ""}
  end

  defp default_sessions_sort do
    %{"column" => "started_at", "direction" => "desc"}
  end

  defp default_cases_filters do
    %{"status" => "", "assigned_agent_id" => "", "query" => ""}
  end

  defp default_cases_sort do
    %{"column" => "updated_at", "direction" => "desc"}
  end

  defp normalize_columns(nil), do: @calls_index_columns

  defp normalize_columns(columns) when is_list(columns) do
    columns =
      columns
      |> Enum.map(&to_string/1)
      |> Enum.uniq()

    normalized = Enum.filter(@calls_index_columns, &(&1 in columns))

    case normalized do
      [] -> @calls_index_columns
      list -> list
    end
  end

  defp normalize_columns(_columns), do: @calls_index_columns

  defp normalize_sessions_columns(nil), do: @sessions_index_columns

  defp normalize_sessions_columns(columns) when is_list(columns) do
    columns =
      columns
      |> Enum.map(&to_string/1)
      |> Enum.uniq()

    normalized = Enum.filter(@sessions_index_columns, &(&1 in columns))

    case normalized do
      [] -> @sessions_index_columns
      list -> list
    end
  end

  defp normalize_sessions_columns(_columns), do: @sessions_index_columns

  defp normalize_cases_columns(nil), do: @cases_index_columns

  defp normalize_cases_columns(columns) when is_list(columns) do
    columns =
      columns
      |> Enum.map(&to_string/1)
      |> Enum.uniq()

    normalized = Enum.filter(@cases_index_columns, &(&1 in columns))

    case normalized do
      [] -> @cases_index_columns
      list -> list
    end
  end

  defp normalize_cases_columns(_columns), do: @cases_index_columns

  defp normalize_filters(nil), do: default_filters()

  defp normalize_filters(filters) when is_map(filters) do
    filters = normalize_map(filters)

    %{
      "status" => normalize_status(Map.get(filters, "status")),
      "agent_id" => normalize_agent_id(Map.get(filters, "agent_id"))
    }
  end

  defp normalize_filters(_filters), do: default_filters()

  defp normalize_sessions_filters(nil), do: default_sessions_filters()

  defp normalize_sessions_filters(filters) when is_map(filters) do
    filters = normalize_map(filters)

    %{
      "status" => normalize_sessions_status(Map.get(filters, "status")),
      "agent_id" => normalize_agent_id(Map.get(filters, "agent_id")),
      "query" => normalize_query(Map.get(filters, "query"))
    }
  end

  defp normalize_sessions_filters(_filters), do: default_sessions_filters()

  defp normalize_cases_filters(nil), do: default_cases_filters()

  defp normalize_cases_filters(filters) when is_map(filters) do
    filters = normalize_map(filters)

    %{
      "status" => normalize_cases_status(Map.get(filters, "status")),
      "assigned_agent_id" => normalize_agent_id(Map.get(filters, "assigned_agent_id")),
      "query" => normalize_query(Map.get(filters, "query"))
    }
  end

  defp normalize_cases_filters(_filters), do: default_cases_filters()

  defp normalize_sort(nil), do: default_sort()

  defp normalize_sort(sort) when is_map(sort) do
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      if to_string(column) in @calls_index_sort_columns do
        to_string(column)
      else
        "started_at"
      end

    direction =
      case direction do
        "asc" -> "asc"
        "desc" -> "desc"
        :asc -> "asc"
        :desc -> "desc"
        _ -> "desc"
      end

    %{"column" => column, "direction" => direction}
  end

  defp normalize_sort(_sort), do: default_sort()

  defp normalize_sessions_sort(nil), do: default_sessions_sort()

  defp normalize_sessions_sort(sort) when is_map(sort) do
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      if to_string(column) in @sessions_index_sort_columns do
        to_string(column)
      else
        "started_at"
      end

    direction =
      case direction do
        "asc" -> "asc"
        "desc" -> "desc"
        :asc -> "asc"
        :desc -> "desc"
        _ -> "desc"
      end

    %{"column" => column, "direction" => direction}
  end

  defp normalize_sessions_sort(_sort), do: default_sessions_sort()

  defp normalize_cases_sort(nil), do: default_cases_sort()

  defp normalize_cases_sort(sort) when is_map(sort) do
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      if to_string(column) in @cases_index_sort_columns do
        to_string(column)
      else
        "updated_at"
      end

    direction =
      case direction do
        "asc" -> "asc"
        "desc" -> "desc"
        :asc -> "asc"
        :desc -> "desc"
        _ -> "desc"
      end

    %{"column" => column, "direction" => direction}
  end

  defp normalize_cases_sort(_sort), do: default_cases_sort()

  defp normalize_status(nil), do: ""
  defp normalize_status(""), do: ""

  defp normalize_status(status) do
    status = to_string(status)

    if status in @calls_index_statuses do
      status
    else
      ""
    end
  end

  defp normalize_sessions_status(nil), do: ""
  defp normalize_sessions_status(""), do: ""

  defp normalize_sessions_status(status) do
    status = to_string(status)

    if status in @sessions_index_statuses do
      status
    else
      ""
    end
  end

  defp normalize_cases_status(nil), do: ""
  defp normalize_cases_status(""), do: ""

  defp normalize_cases_status(status) do
    status = to_string(status)

    if status in @cases_index_statuses do
      status
    else
      ""
    end
  end

  defp normalize_agent_id(nil), do: ""
  defp normalize_agent_id(""), do: ""
  defp normalize_agent_id(agent_id), do: to_string(agent_id)

  defp normalize_query(nil), do: ""
  defp normalize_query(query), do: query |> to_string() |> String.trim()

  defp normalize_map(value) when is_map(value) do
    Map.new(value, fn {key, val} -> {to_string(key), val} end)
  end

  defp normalize_map(_value), do: %{}

  defp deep_merge(left, right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      if is_map(left_val) and is_map(right_val) do
        Map.merge(left_val, right_val)
      else
        right_val
      end
    end)
  end
end
