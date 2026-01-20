defmodule SwatiWeb.SessionsLive.Show do
  use SwatiWeb, :live_view

  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.SessionEvent
  alias SwatiWeb.CallsLive.Show, as: CallsShow

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <CallsShow.call_detail
        call={@call}
        primary_audio_url={@primary_audio_url}
        agent_name={@agent_name}
        status_badge={@status_badge}
        transcript_items={@transcript_items}
        waveform_context_json={@waveform_context_json}
        waveform_duration_ms={@waveform_duration_ms}
        current_scope={@current_scope}
        back_patch={~p"/sessions"}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id

    session =
      Sessions.get_session!(tenant_id, id)
      |> Repo.preload([:agent, events: from(e in SessionEvent, order_by: [asc: e.ts])])

    timeline = Sessions.get_session_timeline(tenant_id, id)

    call_like = build_call_like(session)
    assigns = CallsShow.detail_assigns(call_like, timeline)

    {:ok, assign(socket, assigns)}
  end

  defp build_call_like(session) do
    recording = Sessions.get_session_recording(session.id) || %{}
    transcript = Sessions.get_session_transcript(session.id) || %{}
    metadata = session.metadata || %{}

    %{
      id: session.id,
      status: session.status,
      started_at: session.started_at,
      ended_at: session.ended_at,
      duration_seconds: session_duration_seconds(session),
      recording: recording,
      transcript: transcript,
      from_number: Map.get(metadata, "from_address") || Map.get(metadata, :from_address),
      to_number: Map.get(metadata, "to_address") || Map.get(metadata, :to_address),
      agent: session.agent,
      events: session.events
    }
  end

  defp session_duration_seconds(%{duration_seconds: duration}) when is_integer(duration),
    do: duration

  defp session_duration_seconds(%{
         started_at: %DateTime{} = started_at,
         ended_at: %DateTime{} = ended_at
       }) do
    max(DateTime.diff(ended_at, started_at, :second), 0)
  end

  defp session_duration_seconds(%{started_at: %DateTime{} = started_at, status: status})
       when status in [:open, :active, "open", "active"] do
    max(DateTime.diff(DateTime.utc_now(), started_at, :second), 0)
  end

  defp session_duration_seconds(_session), do: nil
end
