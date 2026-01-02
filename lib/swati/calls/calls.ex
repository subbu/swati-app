defmodule Swati.Calls do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Calls.{Call, CallEvent}

  def create_call_start(attrs) do
    %Call{}
    |> Call.changeset(attrs)
    |> Repo.insert()
  end

  def append_call_event(call_id, type, ts, payload) do
    %CallEvent{}
    |> CallEvent.changeset(%{call_id: call_id, type: type, ts: ts, payload: payload})
    |> Repo.insert()
  end

  def append_call_events(call_id, events) when is_list(events) do
    entries =
      Enum.map(events, fn event ->
        %{
          call_id: call_id,
          type: Map.get(event, "type") || Map.get(event, :type),
          ts: Map.get(event, "ts") || Map.get(event, :ts),
          payload: Map.get(event, "payload") || Map.get(event, :payload),
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    Repo.insert_all(CallEvent, entries)
  end

  def set_call_end(call_id, ended_at, duration, status) do
    Repo.get!(Call, call_id)
    |> Call.changeset(%{ended_at: ended_at, duration_seconds: duration, status: status})
    |> Repo.update()
  end

  def set_call_artifacts(call_id, recording_map, transcript_map) do
    Repo.get!(Call, call_id)
    |> Call.changeset(%{recording: recording_map, transcript: transcript_map})
    |> Repo.update()
  end

  def set_call_summary(call_id, summary, disposition) do
    Repo.get!(Call, call_id)
    |> Call.changeset(%{summary: summary, disposition: disposition})
    |> Repo.update()
  end

  def list_calls(tenant_id, filters \\ %{}) do
    Call
    |> Tenancy.scope(tenant_id)
    |> apply_filters(filters)
    |> Repo.all()
  end

  def get_call!(tenant_id, call_id) do
    Call
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(call_id)
    |> Repo.preload([:agent, :phone_number, events: from(e in CallEvent, order_by: [asc: e.ts])])
  end

  defp apply_filters(query, filters) do
    query
    |> maybe_filter(:status, filters)
    |> maybe_filter(:agent_id, filters)
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(call in query, where: field(call, ^key) == ^value)
    end
  end
end
