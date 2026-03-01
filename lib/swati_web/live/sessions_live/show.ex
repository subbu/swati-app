defmodule SwatiWeb.SessionsLive.Show do
  use SwatiWeb, :live_view

  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Inbound
  alias Swati.Sessions
  alias Swati.Sessions.SessionEvent
  alias SwatiWeb.Formatting
  alias SwatiWeb.CallsLive.Show, as: CallsShow
  alias SwatiWeb.SessionsLive.Helpers, as: SessionsHelpers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-4">
        <section
          :if={@inbound_route}
          class="rounded-base border border-base bg-base-100 p-4 space-y-2"
          id="inbound-route-panel"
        >
          <div class="text-sm font-semibold text-foreground">Inbound routing</div>
          <div class="text-sm text-foreground-soft">
            reason: {@inbound_route.route_reason || "-"} · continuity: {@inbound_route.continuity_strategy} ·
            continuity hit: {@inbound_route.continuity_hit}
          </div>
          <div class="text-xs text-foreground-soft">
            connector: {@inbound_route.connector_id || "-"} · thread: {@inbound_route.thread_key ||
              "-"}
          </div>
          <div class="text-xs text-foreground-soft">
            from: {@inbound_route.from || "-"} · to: {@inbound_route.to || "-"} · subject: {@inbound_route.subject ||
              "-"}
          </div>
        </section>

        <section
          :if={@inbound_ownership_events != []}
          class="rounded-base border border-base bg-base-100 p-4 space-y-2"
          id="inbound-ownership-panel"
        >
          <div class="text-sm font-semibold text-foreground">Thread ownership history</div>
          <div class="space-y-2">
            <article
              :for={event <- @inbound_ownership_events}
              class="rounded-lg border border-base px-3 py-2 text-xs text-foreground-soft"
            >
              <div class="font-medium text-foreground">
                owner: {owner_label(event.owner_agent)} · previous: {owner_label(event.previous_agent)}
              </div>
              <div>
                reason: {event.reason} · source: {event.source} · at: {format_datetime(
                  event.resolved_at,
                  @current_scope.tenant
                )}
              </div>
            </article>
          </div>
        </section>

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
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :view_sessions) do
      tenant_id = socket.assigns.current_scope.tenant.id

      session =
        Sessions.get_session!(tenant_id, id)
        |> Repo.preload([:agent, events: from(e in SessionEvent, order_by: [asc: e.ts])])

      timeline = Sessions.get_session_timeline(tenant_id, id)
      inbound_route = latest_inbound_route(tenant_id, id)

      inbound_ownership_events =
        Inbound.list_thread_ownership_events_for_session(tenant_id, id, limit: 20)

      call_like = SessionsHelpers.build_call_like(session)

      assigns =
        CallsShow.detail_assigns(call_like, timeline)
        |> Map.put(:inbound_route, inbound_route)
        |> Map.put(:inbound_ownership_events, inbound_ownership_events)

      {:ok, assign(socket, assigns)}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  defp latest_inbound_route(tenant_id, session_id) do
    case Inbound.list_deliveries_for_session(tenant_id, session_id) do
      [delivery | _] ->
        route = delivery.route_details || %{}
        normalized = delivery.normalized_payload || %{}

        %{
          route_reason: Map.get(route, "route_reason"),
          continuity_strategy: get_in(route, ["continuity", "strategy"]) || "none",
          continuity_hit: get_in(route, ["continuity", "hit"]) || false,
          connector_id: Map.get(route, "connector_id"),
          thread_key: Map.get(route, "thread_key"),
          subject: Map.get(normalized, "subject"),
          from: Map.get(normalized, "from"),
          to: (Map.get(normalized, "to") || []) |> List.wrap() |> Enum.join(", ")
        }

      _ ->
        nil
    end
  end

  defp format_datetime(nil, _tenant), do: "-"
  defp format_datetime(%DateTime{} = ts, tenant), do: Formatting.datetime(ts, tenant)

  defp owner_label(nil), do: "-"
  defp owner_label(agent), do: agent.name || agent.id
end
