defmodule Swati.Trust do
  alias Swati.Channels
  alias Swati.Trust.Queries

  def list_recent_cases(tenant_id, limit \\ 12) do
    Queries.list_recent_cases(tenant_id, limit)
  end

  def case_timeline(tenant_id, case_id) do
    Queries.list_case_events(tenant_id, case_id)
  end

  def tool_reliability(tenant_id, since \\ default_since()) do
    Queries.list_tool_results(tenant_id, since)
    |> group_tool_results()
  end

  def channel_health(tenant_id) do
    Channels.list_channels(tenant_id)
  end

  defp group_tool_results(results) do
    results
    |> Enum.reduce(%{}, fn result, acc ->
      payload = result.payload || %{}
      name = payload["name"] || payload[:name] || "unknown"
      is_error = payload["isError"] || payload[:isError] || false

      Map.update(acc, name, %{total: 1, errors: error_count(is_error)}, fn entry ->
        %{
          total: entry.total + 1,
          errors: entry.errors + error_count(is_error)
        }
      end)
    end)
    |> Enum.map(fn {name, data} ->
      error_rate = if data.total > 0, do: data.errors / data.total, else: 0.0
      %{name: name, total: data.total, errors: data.errors, error_rate: error_rate}
    end)
    |> Enum.sort_by(& &1.total, :desc)
  end

  defp error_count(true), do: 1
  defp error_count(_), do: 0

  defp default_since do
    DateTime.add(DateTime.utc_now(), -7 * 86_400, :second)
  end
end
