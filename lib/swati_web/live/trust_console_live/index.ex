defmodule SwatiWeb.TrustConsoleLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Cases
  alias Swati.Trust
  alias SwatiWeb.CasesLive.Helpers, as: CasesHelpers
  alias SwatiWeb.Formatting

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    cases = Trust.list_recent_cases(tenant.id)

    {:ok,
     socket
     |> assign(:cases, cases)
     |> assign(:selected_case, nil)
     |> assign(:timeline_events, [])
     |> assign(:active_tab, :timeline)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tenant = socket.assigns.current_scope.tenant
    case_id = Map.get(params, "case_id")

    selected_case =
      case case_id do
        nil ->
          List.first(socket.assigns.cases)

        "" ->
          List.first(socket.assigns.cases)

        id ->
          Enum.find(socket.assigns.cases, &(to_string(&1.id) == to_string(id))) ||
            Cases.get_case!(tenant.id, id)
      end

    timeline_events =
      if selected_case do
        Trust.case_timeline(tenant.id, selected_case.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:selected_case, selected_case)
     |> assign(:timeline_events, timeline_events)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="trust-console" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div>
            <h1 class="text-xl font-semibold text-foreground">Trust Console</h1>
            <p class="text-sm text-foreground-soft">Case-centric audit timeline across sessions.</p>
          </div>
          <div class="flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{length(@cases)}</span>
            <span>cases</span>
          </div>
        </header>

        <nav class="flex flex-wrap items-center gap-2 text-sm">
          <.link patch={~p"/trust"} class={nav_class(@active_tab == :timeline)}>
            Timeline
          </.link>
          <.link patch={~p"/trust/policy"} class={nav_class(@active_tab == :policy)}>
            Policy
          </.link>
          <.link patch={~p"/trust/reliability"} class={nav_class(@active_tab == :reliability)}>
            Reliability
          </.link>
          <.link patch={~p"/trust/rejections"} class={nav_class(@active_tab == :rejections)}>
            Rejections
          </.link>
        </nav>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,280px)_minmax(0,1fr)]">
          <div class="rounded-base border border-base bg-base p-4">
            <h2 class="text-sm font-semibold text-foreground">Recent cases</h2>
            <div id="trust-case-list" class="mt-3 space-y-2">
              <div :if={@cases == []} class="text-sm text-foreground-soft">
                No cases yet.
              </div>
              <.link
                :for={case_record <- @cases}
                patch={~p"/trust?case_id=#{case_record.id}"}
                class={[
                  "block rounded-base border border-base px-3 py-2 transition",
                  if(@selected_case && @selected_case.id == case_record.id,
                    do: "bg-accent text-foreground",
                    else: "hover:bg-accent/60"
                  )
                ]}
              >
                <div class="flex items-center justify-between gap-2">
                  <div class="min-w-0">
                    <div class="truncate text-sm font-medium text-foreground">
                      {case_record.title || "Untitled case"}
                    </div>
                    <div class="text-xs text-foreground-soft">
                      {case_record.category || "General"}
                    </div>
                  </div>
                  <% badge = CasesHelpers.status_badge(case_record.status) %>
                  <.badge size="xs" variant="soft" color={badge.color}>{badge.label}</.badge>
                </div>
              </.link>
            </div>
          </div>

          <div class="rounded-base border border-base bg-base p-4">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-sm font-semibold text-foreground">Case timeline</h2>
                <p class="text-xs text-foreground-soft">All session events ordered by time.</p>
              </div>
              <.badge size="xs" variant="soft" color="info">
                {length(@timeline_events)} events
              </.badge>
            </div>

            <div id="trust-case-timeline" class="mt-4 space-y-3">
              <div :if={@selected_case == nil} class="text-sm text-foreground-soft">
                Select a case to view its timeline.
              </div>
              <div
                :if={@selected_case != nil and @timeline_events == []}
                class="text-sm text-foreground-soft"
              >
                No timeline events yet for this case.
              </div>

              <div
                :for={event <- @timeline_events}
                class="rounded-base border border-base bg-base/60 p-3"
              >
                <div class="flex items-center justify-between gap-2">
                  <div class="flex items-center gap-2">
                    <% category = event.category || "system" %>
                    <.badge size="xs" variant="soft" color={category_color(category)}>
                      {String.replace(category, "_", " ")}
                    </.badge>
                    <span class="text-sm font-medium text-foreground">{event.type}</span>
                  </div>
                  <span class="text-xs text-foreground-soft">
                    {format_ts(event.ts, @current_scope.tenant)}
                  </span>
                </div>
                <div class="mt-2 text-xs text-foreground-soft">
                  {event_summary(event)}
                </div>
                <div :if={event.session_id} class="mt-2 text-xs">
                  <.link
                    navigate={~p"/sessions/#{event.session_id}"}
                    class="font-semibold text-primary hover:text-primary/80"
                  >
                    View session
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_ts(nil, _tenant), do: "—"
  defp format_ts(%DateTime{} = ts, tenant), do: Formatting.datetime(ts, tenant)

  defp event_summary(event) do
    payload = event.payload || %{}

    cond do
      event.type in ["channel.message.received", "channel.message.sent"] ->
        Map.get(payload, "text") || "Message"

      String.starts_with?(to_string(event.type || ""), "tool.") ->
        name = Map.get(payload, "name") || "tool"
        "Tool: #{name}"

      true ->
        "Session #{event.session_external_id || String.slice(to_string(event.session_id), 0, 8)}"
    end
  end

  defp category_color("channel"), do: "info"
  defp category_color("tool"), do: "warning"
  defp category_color("policy"), do: "danger"
  defp category_color("outcome"), do: "success"
  defp category_color("human"), do: "neutral"
  defp category_color("agent"), do: "info"
  defp category_color(_), do: "neutral"

  defp nav_class(true), do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium"
  defp nav_class(false), do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent"
end
