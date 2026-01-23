defmodule Swati.Sessions do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions.Commands
  alias Swati.Sessions.Ingestion
  alias Swati.Sessions.Queries

  alias Swati.Sessions.{
    Session,
    SessionArtifact,
    SessionMarker,
    SessionSpeakerSegment,
    SessionTimelineMeta,
    SessionToolCall,
    SessionUtterance
  }

  def list_sessions(tenant_id, filters \\ %{}) do
    Queries.list_sessions(tenant_id, filters)
  end

  def list_sessions_paginated(tenant_id, filters \\ %{}, flop_params \\ %{}) do
    Queries.list_sessions_paginated(tenant_id, filters, flop_params)
  end

  def get_session!(tenant_id, session_id) do
    Queries.get_session!(tenant_id, session_id)
  end

  def get_session_by_external_id(tenant_id, endpoint_id, external_id) do
    Queries.get_session_by_external_id(tenant_id, endpoint_id, external_id)
  end

  def list_session_events(session_id) do
    Queries.list_session_events(session_id)
  end

  def create_session(tenant_id, attrs) do
    Commands.create_session(tenant_id, attrs)
  end

  def update_session(%Session{} = session, attrs) do
    Commands.update_session(session, attrs)
  end

  def append_events(session_id, events) do
    Ingestion.append_events(session_id, events)
  end

  def end_session(session_id, params) do
    Ingestion.end_session(session_id, params)
  end

  def set_artifacts(session_id, params) do
    Ingestion.set_artifacts(session_id, params)
  end

  def set_timeline(session_id, timeline) do
    Ingestion.set_timeline(session_id, timeline)
  end

  def get_session_artifact(session_id, kind) when is_binary(kind) do
    SessionArtifact
    |> where([a], a.session_id == ^session_id and a.kind == ^kind)
    |> Repo.one()
  end

  def get_session_recording(session_id) do
    case get_session_artifact(session_id, "recording") do
      nil -> nil
      artifact -> artifact.payload
    end
  end

  def get_session_transcript(session_id) do
    case get_session_artifact(session_id, "transcript") do
      nil -> nil
      artifact -> artifact.payload
    end
  end

  def get_session_timeline(tenant_id, session_id) do
    _ =
      Session
      |> Swati.Tenancy.scope(tenant_id)
      |> where([s], s.id == ^session_id)
      |> select([s], s.id)
      |> Repo.one!()

    meta =
      SessionTimelineMeta
      |> where([m], m.session_id == ^session_id)
      |> Repo.one()

    utterances =
      SessionUtterance
      |> where([u], u.session_id == ^session_id)
      |> order_by([u], asc: u.start_ms)
      |> Repo.all()

    speaker_segments =
      SessionSpeakerSegment
      |> where([s], s.session_id == ^session_id)
      |> order_by([s], asc: s.start_ms)
      |> Repo.all()

    tool_calls =
      SessionToolCall
      |> where([t], t.session_id == ^session_id)
      |> order_by([t], asc: t.start_ms)
      |> Repo.all()

    markers =
      SessionMarker
      |> where([m], m.session_id == ^session_id)
      |> order_by([m], asc: m.offset_ms)
      |> Repo.all()

    %{
      meta: meta,
      utterances: utterances,
      speaker_segments: speaker_segments,
      tool_calls: tool_calls,
      markers: markers
    }
  end
end
