defmodule Swati.Sessions.Events do
  @spec normalize(map()) :: map()
  def normalize(event) when is_map(event) do
    %{
      "ts" => parse_datetime(Map.get(event, "ts") || Map.get(event, :ts)),
      "type" => Map.get(event, "type") || Map.get(event, :type),
      "source" => Map.get(event, "source") || Map.get(event, :source),
      "idempotency_key" => Map.get(event, "idempotency_key") || Map.get(event, :idempotency_key),
      "payload" => Map.get(event, "payload") || Map.get(event, :payload)
    }
  end

  def parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :microsecond)

  def parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :microsecond)
      _ -> DateTime.utc_now()
    end
  end

  def parse_datetime(_), do: DateTime.utc_now()
end
