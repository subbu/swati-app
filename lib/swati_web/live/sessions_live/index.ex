defmodule SwatiWeb.SessionsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Repo
  alias Swati.Sessions
  alias SwatiWeb.SessionsLive.Helpers, as: SessionsHelpers

  @impl true
  def mount(_params, _session, socket) do
    filters = %{"status" => ""}

    {:ok,
     socket
     |> assign(:filters, filters)
     |> assign(:status_options, status_options())
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> load_sessions()}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    filters = normalize_filters(filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> load_sessions(reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-emerald-400 to-emerald-600 text-white shadow">
              <.icon name="hero-chat-bubble-left-right" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Sessions</h1>
              <p class="text-sm text-foreground-soft">Track active and resolved conversations.</p>
            </div>
          </div>
          <div class="ml-auto flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{@session_count}</span>
            <span>sessions</span>
          </div>
        </header>

        <section class="rounded-base bg-base overflow-hidden">
          <div class="flex flex-wrap items-center gap-3 px-4 py-3 border-b border-base">
            <.form for={@filter_form} id="sessions-filter" phx-change="filter">
              <.select
                field={@filter_form[:status]}
                label="Status"
                options={@status_options}
                class="min-w-[12rem]"
                native
              />
            </.form>
          </div>

          <div class="overflow-x-auto">
            <.table id="sessions-table">
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col class="py-2">Session</:col>
                <:col class="py-2">Channel</:col>
                <:col class="py-2">Endpoint</:col>
                <:col class="py-2">Status</:col>
                <:col class="py-2">Last activity</:col>
                <:col class="py-2 w-full">Agent</:col>
              </.table_head>
              <.table_body id="sessions" phx-update="stream" class="text-foreground-soft">
                <.table_row
                  :for={{id, session} <- @streams.sessions}
                  id={id}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell class="py-2 align-middle">
                    <.link navigate={~p"/sessions/#{session.id}"} class="text-foreground font-medium">
                      {SessionsHelpers.session_label(session)}
                    </.link>
                    <div class="text-xs text-foreground-softest">
                      {SessionsHelpers.customer_address(session)}
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {session.channel && session.channel.key}
                    </span>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {SessionsHelpers.endpoint_address(session)}
                    </span>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <% badge = SessionsHelpers.status_badge(session.status) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <div class="flex flex-col">
                      <span class="text-foreground font-medium">
                        {SessionsHelpers.format_relative(session.last_event_at, @current_scope.tenant)}
                      </span>
                      <span class="text-xs text-foreground-softest">
                        {SessionsHelpers.format_datetime(session.last_event_at, @current_scope.tenant)}
                      </span>
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {SessionsHelpers.agent_name(session)}
                    </span>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_sessions(socket, opts \\ []) do
    tenant_id = socket.assigns.current_scope.tenant.id

    sessions =
      Sessions.list_sessions(tenant_id, socket.assigns.filters)
      |> Repo.preload([:channel, :endpoint, :agent])

    socket = assign(socket, :session_count, length(sessions))

    if Keyword.get(opts, :reset, false) do
      stream(socket, :sessions, sessions, reset: true)
    else
      stream(socket, :sessions, sessions)
    end
  end

  defp status_options do
    [
      {"All statuses", ""},
      {"Open", "open"},
      {"Active", "active"},
      {"Waiting", "waiting_on_customer"},
      {"Closed", "closed"}
    ]
  end

  defp normalize_filters(filters) when is_map(filters) do
    %{"status" => Map.get(filters, "status") || ""}
  end
end
