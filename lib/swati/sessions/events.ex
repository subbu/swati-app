defmodule Swati.Sessions.Events do
  @spec normalize(map()) :: map()
  def normalize(event) when is_map(event) do
    ts = parse_datetime(Map.get(event, "ts") || Map.get(event, :ts))
    type = Map.get(event, "type") || Map.get(event, :type)
    payload = Map.get(event, "payload") || Map.get(event, :payload)
    source = Map.get(event, "source") || Map.get(event, :source)
    category = category_for_type(type)

    normalized = %{
      "ts" => ts,
      "type" => type,
      "category" => category,
      "source" => source,
      "payload" => payload
    }

    idempotency_key =
      Map.get(event, "idempotency_key") || Map.get(event, :idempotency_key) ||
        idempotency_key(normalized)

    Map.put(normalized, "idempotency_key", idempotency_key)
  end

  def parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :microsecond)

  def parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :microsecond)
      _ -> DateTime.utc_now()
    end
  end

  def parse_datetime(_), do: DateTime.utc_now()

  @spec category_for_type(String.t() | nil) :: String.t()
  def category_for_type(type) when is_binary(type) do
    cond do
      String.starts_with?(type, "channel.") -> "channel"
      String.starts_with?(type, "tool.") -> "tool"
      String.starts_with?(type, "policy.") -> "policy"
      String.starts_with?(type, "outcome.") -> "outcome"
      String.starts_with?(type, "agent.") -> "agent"
      String.starts_with?(type, "human.") -> "human"
      String.starts_with?(type, "approval.") -> "human"
      String.starts_with?(type, "handoff.") -> "human"
      String.starts_with?(type, "case.") -> "outcome"
      type in ["transcript", "call.transcript"] -> "channel"
      true -> "system"
    end
  end

  def category_for_type(_), do: "system"

  @spec idempotency_key(map()) :: String.t()
  def idempotency_key(event) when is_map(event) do
    canonical = canonicalize(event)
    hash = :crypto.hash(:sha256, :erlang.term_to_binary(canonical))
    Base.encode16(hash, case: :lower)
  end

  defp canonicalize(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp canonicalize(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp canonicalize(%Date{} = value), do: Date.to_iso8601(value)
  defp canonicalize(%Time{} = value), do: Time.to_iso8601(value)
  defp canonicalize(%_{} = value), do: value |> Map.from_struct() |> canonicalize()

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), canonicalize(item)} end)
    |> Enum.sort_by(fn {key, _item} -> key end)
  end

  defp canonicalize(value) when is_list(value) do
    Enum.map(value, &canonicalize/1)
  end

  defp canonicalize(value), do: value
end
