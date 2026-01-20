defmodule SwatiWeb.SessionsLive.Show do
  use SwatiWeb, :live_view

  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.SessionEvent
  alias SwatiWeb.CallsLive.Show, as: CallsShow
  alias SwatiWeb.SessionsLive.Helpers, as: SessionsHelpers

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

    call_like = SessionsHelpers.build_call_like(session)
    assigns = CallsShow.detail_assigns(call_like, timeline)

    {:ok, assign(socket, assigns)}
  end
end
