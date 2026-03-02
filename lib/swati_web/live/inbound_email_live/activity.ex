defmodule SwatiWeb.InboundEmailLive.Activity do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Inbound
  alias SwatiWeb.InboundEmailLive.Components
  alias SwatiWeb.InboundEmailLive.Helpers

  @status_options [
    {"All", "all"},
    {"Received", "received"},
    {"Processing", "processing"},
    {"Processed", "processed"},
    {"Failed", "failed"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_channels) do
      tenant_id = socket.assigns.current_scope.tenant.id

      {:ok,
       socket
       |> assign(:tenant_id, tenant_id)
       |> assign(:agents, Agents.list_agents(tenant_id))
       |> assign(:status_filter, "all")
       |> assign(:inbound_enabled, Inbound.enabled?())
       |> load_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> load_data()}
  end

  @impl true
  def handle_event("replay_delivery", %{"id" => id}, socket) do
    delivery = Inbound.get_delivery!(socket.assigns.tenant_id, id)

    case Inbound.replay_delivery(delivery) do
      {:ok, _delivery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery replay queued.")
         |> load_data()}

      {:error, :delivery_busy} ->
        {:noreply, put_flash(socket, :error, "Delivery is already being processed.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to replay delivery: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :status_options, @status_options)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <Components.page_header active_tab="activity" inbound_enabled={@inbound_enabled}>
          <:actions>
            <.button variant="soft" size="sm" phx-click="refresh">
              <.icon name="hero-arrow-path" class="size-3.5" /> Refresh
            </.button>
          </:actions>
        </Components.page_header>

        <%!-- Recent Deliveries --%>
        <section class="space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <Components.section_header title="Recent Deliveries" />
            <Components.status_filter_tabs current={@status_filter} options={@status_options} />
          </div>

          <%= if @deliveries == [] do %>
            <div class="rounded-lg border border-base">
              <Components.empty_state
                icon="hero-inbox-arrow-down"
                title="No deliveries"
                description={if @status_filter != "all", do: "No deliveries with status \"#{@status_filter}\".", else: "No inbound deliveries have been received yet."}
              />
            </div>
          <% else %>
            <div class="space-y-2">
              <Components.delivery_card
                :for={delivery <- @deliveries}
                delivery={delivery}
                agents={@agents}
              />
            </div>
          <% end %>
        </section>

        <%!-- Email Threads --%>
        <section class="space-y-4">
          <Components.section_header
            title="Email Threads"
            description="Active email conversation threads linked to sessions and cases."
          />

          <%= if @email_sessions == [] do %>
            <div class="rounded-lg border border-base">
              <Components.empty_state
                icon="hero-chat-bubble-left-right"
                title="No email threads"
                description="Email threads will appear here once inbound emails are processed."
              />
            </div>
          <% else %>
            <%!-- Desktop: table, Mobile: cards --%>
            <div class="rounded-lg border border-base overflow-hidden max-lg:hidden">
              <.table id="email-threads-table">
                <.table_head>
                  <:col>Thread</:col>
                  <:col>Customer</:col>
                  <:col>Endpoint</:col>
                  <:col>Owner</:col>
                  <:col>Case</:col>
                  <:col>Last activity</:col>
                </.table_head>
                <.table_body>
                  <.table_row :for={session <- @email_sessions}>
                    <:cell>
                      <.link navigate={~p"/sessions/#{session.id}"} class="link font-medium">
                        {session.external_id || session.id}
                      </.link>
                    </:cell>
                    <:cell>{session.customer && session.customer.primary_email}</:cell>
                    <:cell class="text-foreground-softer">
                      {session.endpoint && session.endpoint.address}
                    </:cell>
                    <:cell>{session.agent && session.agent.name}</:cell>
                    <:cell>
                      <.link
                        :if={session.case_id}
                        navigate={~p"/cases/#{session.case_id}"}
                        class="link"
                      >
                        {session.case_id}
                      </.link>
                      <span :if={!session.case_id} class="text-foreground-softer">-</span>
                    </:cell>
                    <:cell class="text-foreground-softer">
                      {Helpers.relative_time(session.last_event_at || session.inserted_at)}
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>

            <%!-- Mobile: card list --%>
            <div class="lg:hidden space-y-2">
              <article
                :for={session <- @email_sessions}
                class="rounded-lg border border-base bg-base p-4 space-y-2"
              >
                <div class="flex items-center justify-between">
                  <.link navigate={~p"/sessions/#{session.id}"} class="link font-medium text-sm">
                    {session.external_id || session.id}
                  </.link>
                  <span class="text-xs text-foreground-softer">
                    {Helpers.relative_time(session.last_event_at || session.inserted_at)}
                  </span>
                </div>
                <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-foreground-softer">
                  <span :if={session.customer && session.customer.primary_email}>
                    {session.customer.primary_email}
                  </span>
                  <span :if={session.agent}>
                    Agent: {session.agent.name}
                  </span>
                  <.link
                    :if={session.case_id}
                    navigate={~p"/cases/#{session.case_id}"}
                    class="link"
                  >
                    Case
                  </.link>
                </div>
              </article>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id
    status_filter = socket.assigns.status_filter

    filters =
      if status_filter != "all",
        do: %{status: status_filter},
        else: %{}

    socket
    |> assign(:deliveries, Inbound.list_deliveries(tenant_id, limit: 50, filters: filters))
    |> assign(:email_sessions, Inbound.list_email_sessions(tenant_id, limit: 50))
  end
end
