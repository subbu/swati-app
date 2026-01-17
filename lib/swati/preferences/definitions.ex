defmodule Swati.Preferences.Definitions do
  @moduledoc false

  @calls_index_key "calls.index.view_state"
  @calls_index_columns ~w(direction started_at from_number duration_seconds status agent_id)
  @calls_index_statuses ~w(started in_progress ended failed cancelled error)
  @calls_index_sort_columns ~w(started_at from_number duration_seconds status agent_id)

  def calls_index_key, do: @calls_index_key
  def calls_index_columns, do: @calls_index_columns
  def calls_index_defaults, do: default(@calls_index_key)

  def schema_version(@calls_index_key), do: 1

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

  def normalize(key, _value) do
    raise ArgumentError, "unknown preference key: #{inspect(key)}"
  end

  def merge(@calls_index_key, existing, updates) do
    existing = normalize(@calls_index_key, existing)
    updates = normalize_map(updates)
    merged = deep_merge(existing, updates)

    normalize(@calls_index_key, merged)
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

  defp normalize_filters(nil), do: default_filters()

  defp normalize_filters(filters) when is_map(filters) do
    filters = normalize_map(filters)

    %{
      "status" => normalize_status(Map.get(filters, "status")),
      "agent_id" => normalize_agent_id(Map.get(filters, "agent_id"))
    }
  end

  defp normalize_filters(_filters), do: default_filters()

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

  defp normalize_agent_id(nil), do: ""
  defp normalize_agent_id(""), do: ""
  defp normalize_agent_id(agent_id), do: to_string(agent_id)

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
