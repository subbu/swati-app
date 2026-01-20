defmodule SwatiWeb.CasesLive.Show do
  use SwatiWeb, :live_view

  alias Swati.Approvals
  alias Swati.Cases
  alias Swati.Handoffs
  alias Swati.Repo
  alias Swati.Sessions
  alias SwatiWeb.CasesLive.Helpers, as: CasesHelpers
  alias SwatiWeb.SessionsLive.Helpers, as: SessionsHelpers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id

    case_record =
      Cases.get_case!(tenant_id, id)
      |> Repo.preload([:customer])

    sessions =
      Sessions.list_sessions(tenant_id, %{case_id: case_record.id})
      |> Repo.preload([:channel, :endpoint, :agent])

    approvals = Approvals.list_approvals(tenant_id, %{case_id: case_record.id})
    handoffs = Handoffs.list_handoffs(tenant_id, %{case_id: case_record.id})

    {:ok,
     socket
     |> assign(:case_record, case_record)
     |> assign(:memory, case_record.memory || %{})
     |> assign(:approvals, approvals)
     |> assign(:handoffs, handoffs)
     |> stream(:sessions, sessions)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <header class="flex flex-wrap items-start justify-between gap-4 border-b border-base pb-4">
          <div class="space-y-2">
            <div class="flex items-center gap-2">
              <% status_badge = CasesHelpers.status_badge(@case_record.status) %>
              <% priority_badge = CasesHelpers.priority_badge(@case_record.priority) %>
              <.badge size="sm" variant="soft" color={status_badge.color}>
                {status_badge.label}
              </.badge>
              <.badge size="sm" variant="soft" color={priority_badge.color}>
                {priority_badge.label}
              </.badge>
            </div>
            <h1 class="text-2xl font-semibold text-foreground">
              {@case_record.title || "Untitled case"}
            </h1>
            <p class="text-sm text-foreground-soft">
              {CasesHelpers.customer_name(@case_record)} · {@case_record.category || "General"}
            </p>
          </div>
          <div class="text-sm text-foreground-soft">
            Updated {CasesHelpers.format_relative(@case_record.updated_at, @current_scope.tenant)}
          </div>
        </header>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,320px)]">
          <div class="space-y-4">
            <div class="rounded-base border border-base bg-base p-4">
              <h2 class="text-sm font-semibold text-foreground">Case memory</h2>
              <p class="mt-2 text-sm text-foreground-soft">
                {Map.get(@memory, "summary") || "No summary yet."}
              </p>
            </div>

            <div class="rounded-base border border-base bg-base p-4">
              <h2 class="text-sm font-semibold text-foreground">Sessions</h2>
              <div class="mt-3 overflow-x-auto">
                <.table id="case-sessions-table">
                  <.table_head class="text-foreground-soft [&_th:first-child]:pl-3!">
                    <:col class="py-2">Session</:col>
                    <:col class="py-2">Channel</:col>
                    <:col class="py-2">Status</:col>
                    <:col class="py-2 w-full">Last activity</:col>
                  </.table_head>
                  <.table_body id="case-sessions" phx-update="stream" class="text-foreground-soft">
                    <.table_row
                      :for={{id, session} <- @streams.sessions}
                      id={id}
                      class="[&_td:first-child]:pl-3! [&_td:last-child]:pr-3! hover:bg-accent/50 transition-colors"
                    >
                      <:cell class="py-2 align-middle">
                        <.link
                          navigate={~p"/sessions/#{session.id}"}
                          class="text-foreground font-medium"
                        >
                          {SessionsHelpers.session_label(session)}
                        </.link>
                        <div class="text-xs text-foreground-softest">
                          {SessionsHelpers.endpoint_address(session)}
                        </div>
                      </:cell>
                      <:cell class="py-2 align-middle">
                        <span class="text-foreground font-medium">
                          {session.channel && session.channel.key}
                        </span>
                      </:cell>
                      <:cell class="py-2 align-middle">
                        <% badge = SessionsHelpers.status_badge(session.status) %>
                        <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                      </:cell>
                      <:cell class="py-2 align-middle">
                        <span class="text-foreground font-medium">
                          {SessionsHelpers.format_relative(
                            session.last_event_at,
                            @current_scope.tenant
                          )}
                        </span>
                      </:cell>
                    </.table_row>
                  </.table_body>
                </.table>
              </div>
            </div>
          </div>

          <div class="space-y-4">
            <div class="rounded-base border border-base bg-base p-4">
              <h2 class="text-sm font-semibold text-foreground">Commitments</h2>
              <ul class="mt-2 space-y-1 text-sm text-foreground-soft">
                <li :for={item <- Map.get(@memory, "commitments", [])}>
                  {item}
                </li>
                <li :if={Map.get(@memory, "commitments", []) == []}>
                  No commitments tracked.
                </li>
              </ul>
            </div>
            <div class="rounded-base border border-base bg-base p-4">
              <h2 class="text-sm font-semibold text-foreground">Next actions</h2>
              <ul class="mt-2 space-y-1 text-sm text-foreground-soft">
                <li :for={item <- Map.get(@memory, "next_actions", [])}>
                  {item}
                </li>
                <li :if={Map.get(@memory, "next_actions", []) == []}>
                  No next actions yet.
                </li>
              </ul>
            </div>

            <div class="rounded-base border border-base bg-base p-4">
              <div class="flex items-center justify-between">
                <h2 class="text-sm font-semibold text-foreground">Approvals</h2>
                <.badge size="xs" variant="soft" color="info">{length(@approvals)}</.badge>
              </div>
              <div :if={@approvals == []} class="mt-2 text-sm text-foreground-soft">
                No approvals logged.
              </div>
              <div :if={@approvals != []} class="mt-2 space-y-2">
                <div :for={approval <- @approvals} class="flex items-center justify-between">
                  <div>
                    <div class="text-sm font-medium text-foreground">
                      {approval.requested_by_type || "Agent"} approval request
                    </div>
                    <div class="text-xs text-foreground-soft">
                      {SessionsHelpers.format_relative(
                        approval.requested_at || approval.inserted_at,
                        @current_scope.tenant
                      )}
                    </div>
                  </div>
                  <% badge = SessionsHelpers.approval_status_badge(approval.status) %>
                  <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                </div>
              </div>
            </div>

            <div class="rounded-base border border-base bg-base p-4">
              <div class="flex items-center justify-between">
                <h2 class="text-sm font-semibold text-foreground">Handoffs</h2>
                <.badge size="xs" variant="soft" color="info">{length(@handoffs)}</.badge>
              </div>
              <div :if={@handoffs == []} class="mt-2 text-sm text-foreground-soft">
                No handoffs logged.
              </div>
              <div :if={@handoffs != []} class="mt-2 space-y-2">
                <div :for={handoff <- @handoffs} class="flex items-center justify-between">
                  <div>
                    <div class="text-sm font-medium text-foreground">
                      {handoff.requested_by_type || "Agent"} handoff request
                    </div>
                    <div class="text-xs text-foreground-soft">
                      {SessionsHelpers.format_relative(
                        handoff.requested_at || handoff.inserted_at,
                        @current_scope.tenant
                      )}
                    </div>
                  </div>
                  <% badge = SessionsHelpers.handoff_status_badge(handoff.status) %>
                  <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
