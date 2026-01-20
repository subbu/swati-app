defmodule Swati.Sessions.Ingestion do
  import Ecto.Query, warn: false

  alias Swati.Cases
  alias Swati.Repo
  alias Swati.Sessions.Commands
  alias Swati.Sessions.Events
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionArtifact
  alias Swati.Sessions.SessionEvent
  alias Swati.Sessions.Timeline

  @spec start(map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def start(params) when is_map(params) do
    tenant_id = Map.get(params, "tenant_id") || Map.get(params, :tenant_id)
    Commands.create_session(tenant_id, params)
  end

  @spec append_events(binary(), list(map())) :: :ok
  def append_events(session_id, events) when is_list(events) do
    parsed_events = Enum.map(events, &Events.normalize/1)
    now = DateTime.utc_now()

    entries =
      Enum.map(parsed_events, fn event ->
        %{
          session_id: session_id,
          ts: Map.get(event, "ts"),
          type: Map.get(event, "type"),
          source: Map.get(event, "source"),
          idempotency_key: Map.get(event, "idempotency_key"),
          payload: Map.get(event, "payload"),
          inserted_at: now,
          updated_at: now
        }
      end)

    _ =
      Repo.insert_all(SessionEvent, entries,
        on_conflict: :nothing,
        conflict_target: [:session_id, :idempotency_key]
      )

    last_event_at =
      parsed_events
      |> Enum.map(&Map.get(&1, "ts"))
      |> Enum.reject(&is_nil/1)
      |> case do
        [] -> nil
        values -> Enum.max_by(values, &DateTime.to_unix/1)
      end

    session = Repo.get!(Session, session_id)

    if last_event_at do
      session =
        if session.status in [:open] do
          {:ok, updated} = Commands.update_session(session, %{status: :active})
          updated
        else
          session
        end

      _ = Commands.touch_last_event(session, last_event_at)
    end

    if session.case_id do
      case_record = Repo.get!(Swati.Cases.Case, session.case_id)
      _ = Cases.update_memory(case_record, parsed_events)
    end

    :ok
  end

  @spec end_session(binary(), map()) :: {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def end_session(session_id, params) when is_map(params) do
    ended_at = Events.parse_datetime(Map.get(params, "ended_at") || Map.get(params, :ended_at))
    status = Map.get(params, "status") || Map.get(params, :status) || :closed

    session = Repo.get!(Session, session_id)
    Commands.set_session_end(session, ended_at, status)
  end

  @spec set_artifacts(binary(), map()) :: :ok
  def set_artifacts(session_id, params) when is_map(params) do
    artifacts =
      params
      |> Map.get("artifacts")
      |> case do
        nil -> params
        value -> value
      end

    upsert_artifact(
      session_id,
      "recording",
      Map.get(artifacts, "recording") || Map.get(artifacts, :recording)
    )

    upsert_artifact(
      session_id,
      "transcript",
      Map.get(artifacts, "transcript") || Map.get(artifacts, :transcript)
    )

    :ok
  end

  @spec set_timeline(binary(), map()) :: :ok | {:error, term()}
  def set_timeline(session_id, timeline) when is_map(timeline) do
    Timeline.upsert(session_id, timeline)
  end

  defp upsert_artifact(_session_id, _kind, nil), do: :ok

  defp upsert_artifact(session_id, kind, payload) do
    Repo.delete_all(
      from(a in SessionArtifact, where: a.session_id == ^session_id and a.kind == ^kind)
    )

    %SessionArtifact{}
    |> SessionArtifact.changeset(%{session_id: session_id, kind: kind, payload: payload})
    |> Repo.insert()

    :ok
  end
end
