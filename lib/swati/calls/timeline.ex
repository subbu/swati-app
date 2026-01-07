defmodule Swati.Calls.Timeline do
  import Ecto.Query, warn: false

  alias Swati.Calls.Events

  alias Swati.Calls.{
    CallMarker,
    CallSpeakerSegment,
    CallTimelineMeta,
    CallToolCall,
    CallUtterance
  }

  alias Swati.Repo

  @spec upsert(binary(), map()) :: :ok | {:error, term()}
  def upsert(call_id, payload) when is_binary(call_id) and is_map(payload) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    meta = build_meta(call_id, payload, now)
    utterances = build_utterances(call_id, payload, now)
    segments = build_segments(call_id, payload, now)
    tool_calls = build_tool_calls(call_id, payload, now)
    markers = build_markers(call_id, payload, now)

    Repo.transaction(fn ->
      Repo.insert_all(CallTimelineMeta, [meta],
        on_conflict:
          {:replace, [:origin_ts, :origin_type, :duration_ms, :version, :built_at, :updated_at]},
        conflict_target: [:call_id]
      )

      Repo.delete_all(from(u in CallUtterance, where: u.call_id == ^call_id))
      Repo.delete_all(from(s in CallSpeakerSegment, where: s.call_id == ^call_id))
      Repo.delete_all(from(t in CallToolCall, where: t.call_id == ^call_id))
      Repo.delete_all(from(m in CallMarker, where: m.call_id == ^call_id))

      insert_all(CallUtterance, utterances)
      insert_all(CallSpeakerSegment, segments)
      insert_all(CallToolCall, tool_calls)
      insert_all(CallMarker, markers)
    end)

    :ok
  rescue
    Ecto.ConstraintError -> {:error, :constraint}
    Ecto.InvalidChangesetError -> {:error, :invalid}
  end

  defp insert_all(_schema, []), do: :ok
  defp insert_all(schema, rows), do: Repo.insert_all(schema, rows)

  defp build_meta(call_id, payload, now) do
    origin = map_value(payload, "origin", :origin) || %{}
    origin_ts = parse_optional_datetime(map_value(origin, "ts", :ts)) || now
    origin_type = map_value(origin, "type", :type) || "event"
    duration_ms = parse_int(map_value(payload, "duration_ms", :duration_ms))
    version = parse_int(map_value(payload, "version", :version)) || 1
    built_at = parse_optional_datetime(map_value(payload, "generated_at", :generated_at))

    %{
      call_id: call_id,
      origin_ts: origin_ts,
      origin_type: origin_type,
      duration_ms: duration_ms,
      version: version,
      built_at: built_at,
      inserted_at: now,
      updated_at: now
    }
  end

  defp build_utterances(call_id, payload, now) do
    utterances = map_value(payload, "utterances", :utterances) || []

    Enum.flat_map(utterances, fn item ->
      start_ms = parse_int(map_value(item, "start_ms", :start_ms))
      end_ms = parse_int(map_value(item, "end_ms", :end_ms)) || start_ms
      speaker = map_value(item, "speaker", :speaker)
      text = map_value(item, "text", :text)

      if is_nil(start_ms) or is_nil(end_ms) or is_nil(speaker) or is_nil(text) do
        []
      else
        [
          %{
            call_id: call_id,
            speaker: to_string(speaker),
            start_ms: start_ms,
            end_ms: max(end_ms, start_ms),
            text: to_string(text),
            event_indexes: map_value(item, "event_indexes", :event_indexes),
            inserted_at: now,
            updated_at: now
          }
        ]
      end
    end)
  end

  defp build_segments(call_id, payload, now) do
    segments = map_value(payload, "speaker_segments", :speaker_segments) || []

    Enum.flat_map(segments, fn item ->
      start_ms = parse_int(map_value(item, "start_ms", :start_ms))
      end_ms = parse_int(map_value(item, "end_ms", :end_ms)) || start_ms
      speaker = map_value(item, "speaker", :speaker)
      energy_avg = map_value(item, "energy_avg", :energy_avg)

      if is_nil(start_ms) or is_nil(end_ms) or is_nil(speaker) do
        []
      else
        [
          %{
            call_id: call_id,
            speaker: to_string(speaker),
            start_ms: start_ms,
            end_ms: max(end_ms, start_ms),
            energy_avg: parse_float(energy_avg),
            inserted_at: now,
            updated_at: now
          }
        ]
      end
    end)
  end

  defp build_tool_calls(call_id, payload, now) do
    tool_calls = map_value(payload, "tool_calls", :tool_calls) || []

    Enum.flat_map(tool_calls, fn item ->
      name = map_value(item, "name", :name)
      status = map_value(item, "status", :status)
      start_ms = parse_int(map_value(item, "start_ms", :start_ms))
      end_ms = parse_int(map_value(item, "end_ms", :end_ms)) || start_ms

      if is_nil(name) or is_nil(status) or is_nil(start_ms) or is_nil(end_ms) do
        []
      else
        [
          %{
            call_id: call_id,
            name: to_string(name),
            status: to_string(status),
            start_ms: start_ms,
            end_ms: max(end_ms, start_ms),
            latency_ms: parse_int(map_value(item, "latency_ms", :latency_ms)),
            args: map_value(item, "args", :args),
            response_summary: map_value(item, "response_summary", :response_summary),
            mcp_endpoint: map_value(item, "mcp_endpoint", :mcp_endpoint),
            mcp_session_id: map_value(item, "mcp_session_id", :mcp_session_id),
            inserted_at: now,
            updated_at: now
          }
        ]
      end
    end)
  end

  defp build_markers(call_id, payload, now) do
    markers = map_value(payload, "markers", :markers) || []

    Enum.flat_map(markers, fn item ->
      kind = map_value(item, "type", :type) || map_value(item, "kind", :kind)
      offset_ms = parse_int(map_value(item, "offset_ms", :offset_ms))

      if is_nil(kind) or is_nil(offset_ms) do
        []
      else
        [
          %{
            call_id: call_id,
            kind: to_string(kind),
            offset_ms: offset_ms,
            payload: map_value(item, "payload", :payload),
            inserted_at: now,
            updated_at: now
          }
        ]
      end
    end)
  end

  defp map_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp parse_optional_datetime(nil), do: nil
  defp parse_optional_datetime(value), do: Events.parse_datetime(value)

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_float(value), do: trunc(value)

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_int(_), do: nil

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_float(_), do: nil
end
