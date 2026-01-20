defmodule SwatiWeb.SessionsLive.Index do
  use SwatiWeb, :live_view

  import Ecto.Query, warn: false

  alias Swati.Agents
  alias Swati.Preferences
  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.SessionEvent
  alias SwatiWeb.CallsLive.Show, as: CallsShow
  alias SwatiWeb.SessionsLive.Helpers, as: SessionsHelpers

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    view_state = Preferences.sessions_index_state(socket.assigns.current_scope)
    allowed_columns = Preferences.sessions_index_columns()
    default_sort = Map.get(Preferences.sessions_index_defaults(), "sort", %{})

    filters =
      %{"status" => "", "agent_id" => "", "query" => ""}
      |> Map.merge(Map.get(view_state, "filters", %{}))

    sort =
      view_state
      |> Map.get("sort", default_sort)
      |> sort_assign()

    visible_columns = Map.get(view_state, "columns", allowed_columns)
    hidden_columns_count = max(length(allowed_columns) - length(visible_columns), 0)

    {filters, filters_changed?} = normalize_agent_filter(filters, agents)
    filters_active = filters_active?(filters)

    socket =
      socket
      |> assign(:agents, agents)
      |> assign(:filters, filters)
      |> assign(:filters_active, filters_active)
      |> assign(:filter_form, to_form(filters, as: :filters))
      |> assign(:status_options, SessionsHelpers.status_options())
      |> assign(:agent_options, SessionsHelpers.agent_options(agents))
      |> assign(:sort, sort)
      |> assign(:visible_columns, visible_columns)
      |> assign(:hidden_columns_count, hidden_columns_count)
      |> assign(
        :columns_form,
        visible_columns
        |> columns_form_map(allowed_columns)
        |> to_form()
      )
      |> assign(:session_sheet_open, false)
      |> assign(:call, nil)

    _ =
      if filters_changed? do
        persist_session_filters(socket, filters)
      else
        :ok
      end

    {:ok, load_sessions(socket)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    tenant = socket.assigns.current_scope.tenant
    session_id = SessionsHelpers.parse_id(id)

    if is_nil(session_id) do
      {:noreply, push_patch(socket, to: ~p"/sessions")}
    else
      session =
        Sessions.get_session!(tenant.id, session_id)
        |> Repo.preload([:agent, events: from(e in SessionEvent, order_by: [asc: e.ts])])

      timeline = Sessions.get_session_timeline(tenant.id, session_id)
      call_like = SessionsHelpers.build_call_like(session)

      {:noreply,
       socket
       |> assign(CallsShow.detail_assigns(call_like, timeline))
       |> assign(session_sheet_open: true)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, session_sheet_open: false, call: nil)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    merged_filters = Map.merge(socket.assigns.filters, filters)
    filters_active = filters_active?(merged_filters)

    if merged_filters != socket.assigns.filters do
      persist_session_filters(socket, merged_filters)
    end

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, filters_active)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> load_sessions(reset: true)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    default_filters = Map.get(Preferences.sessions_index_defaults(), "filters", %{})
    merged_filters = Map.merge(socket.assigns.filters, default_filters)

    persist_session_filters(socket, default_filters)

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> load_sessions(reset: true)}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    sort = SessionsHelpers.next_sort(socket.assigns.sort, column)
    persist_sort(socket, sort)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> load_sessions(reset: true)}
  end

  @impl true
  def handle_event("update_columns", columns, socket) do
    allowed_columns = Preferences.sessions_index_columns()

    visible_columns =
      Enum.filter(allowed_columns, fn column ->
        Phoenix.HTML.Form.normalize_value("checkbox", Map.get(columns, column))
      end)

    hidden_columns_count = max(length(allowed_columns) - length(visible_columns), 0)

    if visible_columns != socket.assigns.visible_columns do
      _ =
        Preferences.update_sessions_index_state(socket.assigns.current_scope, %{
          "columns" => visible_columns
        })
    end

    columns_form =
      visible_columns
      |> columns_form_map(allowed_columns)
      |> to_form()

    {:noreply,
     assign(socket,
       columns_form: columns_form,
       visible_columns: visible_columns,
       hidden_columns_count: hidden_columns_count
     )}
  end

  @impl true
  def handle_event("reset_columns", _params, socket) do
    default_columns = Preferences.sessions_index_columns()
    hidden_columns_count = 0

    _ =
      Preferences.update_sessions_index_state(socket.assigns.current_scope, %{
        "columns" => default_columns
      })

    columns_form =
      default_columns
      |> columns_form_map(default_columns)
      |> to_form()

    {:noreply,
     assign(socket,
       columns_form: columns_form,
       visible_columns: default_columns,
       hidden_columns_count: hidden_columns_count
     )}
  end

  @impl true
  def handle_event("open-session-sheet", %{"id" => id}, socket) do
    session_id = SessionsHelpers.parse_id(id)

    if is_nil(session_id) do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: ~p"/sessions/#{session_id}")}
    end
  end

  @impl true
  def handle_event("close-session-sheet", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/sessions")}
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
          <div class="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-base">
            <.form
              for={@filter_form}
              id="sessions-filter"
              phx-change="filter"
              class="flex items-center gap-2"
            >
              <.input
                field={@filter_form[:query]}
                type="text"
                placeholder="Search sessions"
                phx-debounce="300"
                class="min-w-[16rem] lg:min-w-[20rem]"
              >
                <:inner_prefix>
                  <.icon name="hero-magnifying-glass" class="icon" />
                </:inner_prefix>
              </.input>
            </.form>

            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-adjustments-horizontal" class="icon" />
                  <span class="hidden lg:inline ml-1">
                    {SessionsHelpers.status_filter_label(@filters)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"status" => ""}})}>
                All statuses
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- @status_options |> Enum.reject(&(elem(&1, 1) == ""))}
                phx-click={JS.push("filter", value: %{filters: %{"status" => value}})}
              >
                {label}
              </.dropdown_button>
            </.dropdown>

            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-user-circle" class="icon" />
                  <span class="hidden lg:inline ml-1">
                    {SessionsHelpers.agent_filter_label(@filters, @agents)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"agent_id" => ""}})}>
                All agents
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- @agent_options |> Enum.reject(&(elem(&1, 1) == ""))}
                phx-click={JS.push("filter", value: %{filters: %{"agent_id" => value}})}
              >
                {label}
              </.dropdown_button>
            </.dropdown>

            <.popover
              id="sessions-columns-popover"
              placement="bottom-start"
              class="min-w-56 [&:has(.phx-change-loading)_[data-loading]]:flex"
            >
              <.button variant="dashed">
                <.icon name="hero-view-columns" class="icon" />
                <span class="hidden lg:inline ml-1">Columns</span>
                <.badge
                  :if={@hidden_columns_count > 0}
                  size="xs"
                  variant="solid"
                  color="info"
                  class="ml-2"
                >
                  {@hidden_columns_count}
                </.badge>
              </.button>
              <:content>
                <div
                  class="absolute inset-px bg-base/70 items-center justify-center hidden"
                  data-loading
                >
                  <.loading class="text-foreground-softer" />
                </div>
                <div class="flex items-center justify-between">
                  <h3 class="font-medium">Columns</h3>
                  <.button size="xs" variant="ghost" type="button" phx-click="reset_columns">
                    Reset
                  </.button>
                </div>
                <.form for={@columns_form} id="sessions-columns-form" phx-change="update_columns">
                  <div class="flex items-center justify-between mt-3">
                    <.label for="session" class="text-foreground">Session</.label>
                    <.switch
                      id="session"
                      field={@columns_form[:session]}
                      value={@visible_columns |> Enum.member?("session")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="customer" class="text-foreground">Customer</.label>
                    <.switch
                      id="customer"
                      field={@columns_form[:customer]}
                      value={@visible_columns |> Enum.member?("customer")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="channel" class="text-foreground">Channel</.label>
                    <.switch
                      id="channel"
                      field={@columns_form[:channel]}
                      value={@visible_columns |> Enum.member?("channel")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="endpoint" class="text-foreground">Endpoint</.label>
                    <.switch
                      id="endpoint"
                      field={@columns_form[:endpoint]}
                      value={@visible_columns |> Enum.member?("endpoint")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="direction" class="text-foreground">Direction</.label>
                    <.switch
                      id="direction"
                      field={@columns_form[:direction]}
                      value={@visible_columns |> Enum.member?("direction")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="status" class="text-foreground">Status</.label>
                    <.switch
                      id="status"
                      field={@columns_form[:status]}
                      value={@visible_columns |> Enum.member?("status")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="last_event_at" class="text-foreground">Last activity</.label>
                    <.switch
                      id="last_event_at"
                      field={@columns_form[:last_event_at]}
                      value={@visible_columns |> Enum.member?("last_event_at")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="agent" class="text-foreground">Agent</.label>
                    <.switch
                      id="agent"
                      field={@columns_form[:agent]}
                      value={@visible_columns |> Enum.member?("agent")}
                    />
                  </div>
                </.form>
              </:content>
            </.popover>

            <%= if @filters_active do %>
              <.button
                size="xs"
                variant="ghost"
                type="button"
                phx-click="reset_filters"
                aria-label="Reset filters"
              >
                <.icon name="hero-x-mark" class="icon" />
                <span class="hidden lg:inline ml-1">Reset filters</span>
              </.button>
            <% end %>
          </div>

          <div class="overflow-x-auto">
            <.table id="sessions-table">
            <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
              <:col :if={"session" in @visible_columns} class="py-2" data-column="session">
                Session
              </:col>
              <:col :if={"customer" in @visible_columns} class="py-2" data-column="customer">
                Customer
              </:col>
              <:col :if={"channel" in @visible_columns} class="py-2" data-column="channel">
                Channel
              </:col>
              <:col :if={"endpoint" in @visible_columns} class="py-2" data-column="endpoint">
                Endpoint
              </:col>
              <:col
                :if={"direction" in @visible_columns}
                class="py-2"
                phx-click="sort"
                phx-value-column="direction"
                data-column="direction"
              >
                <button type="button" class={SessionsHelpers.sort_button_class("direction", @sort)}>
                  Direction <SessionsHelpers.sort_icon column="direction" sort={@sort} />
                </button>
              </:col>
              <:col
                :if={"status" in @visible_columns}
                class="py-2"
                phx-click="sort"
                phx-value-column="status"
                data-column="status"
              >
                <button type="button" class={SessionsHelpers.sort_button_class("status", @sort)}>
                  Status <SessionsHelpers.sort_icon column="status" sort={@sort} />
                </button>
              </:col>
              <:col
                :if={"last_event_at" in @visible_columns}
                class="py-2"
                phx-click="sort"
                phx-value-column="last_event_at"
                data-column="last_event_at"
              >
                <button
                  type="button"
                  class={SessionsHelpers.sort_button_class("last_event_at", @sort)}
                >
                  Last activity <SessionsHelpers.sort_icon column="last_event_at" sort={@sort} />
                </button>
              </:col>
              <:col :if={"agent" in @visible_columns} class="py-2 w-full" data-column="agent">
                Agent
              </:col>
              <:col class="py-2 text-right"></:col>
            </.table_head>
              <.table_body id="sessions" phx-update="stream" class="text-foreground-soft">
                <.table_row
                  :for={{id, session} <- @streams.sessions}
                  id={id}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell :if={"session" in @visible_columns} class="py-2 align-middle">
                    <.link patch={~p"/sessions/#{session.id}"} class="text-foreground font-medium">
                      {SessionsHelpers.session_label(session)}
                    </.link>
                    <div class="text-xs text-foreground-softest">
                      {SessionsHelpers.endpoint_address(session)}
                    </div>
                  </:cell>
                  <:cell :if={"customer" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {SessionsHelpers.customer_name(session)}
                    </span>
                    <div class="text-xs text-foreground-softest">
                      {SessionsHelpers.customer_address(session)}
                    </div>
                  </:cell>
                  <:cell :if={"channel" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {session.channel && session.channel.key}
                    </span>
                  </:cell>
                  <:cell :if={"endpoint" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {SessionsHelpers.endpoint_address(session)}
                    </span>
                  </:cell>
                  <:cell :if={"direction" in @visible_columns} class="py-2 align-middle">
                    <% direction = SessionsHelpers.direction_display(session) %>
                    <div class="flex items-center gap-x-2">
                      <.icon name={direction.icon_name} class={"size-5 #{direction.icon_class}"} />
                      <span>{direction.label}</span>
                    </div>
                  </:cell>
                  <:cell :if={"status" in @visible_columns} class="py-2 align-middle">
                    <% badge = SessionsHelpers.status_badge(session.status) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell :if={"last_event_at" in @visible_columns} class="py-2 align-middle">
                    <% activity_at = session.last_event_at || session.started_at %>
                    <div class="flex flex-col">
                      <span class="text-foreground font-medium">
                        {SessionsHelpers.format_relative(activity_at, @current_scope.tenant)}
                      </span>
                      <span class="text-xs text-foreground-softest">
                        {SessionsHelpers.format_datetime(activity_at, @current_scope.tenant)}
                      </span>
                    </div>
                  </:cell>
                  <:cell :if={"agent" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {SessionsHelpers.agent_name(session)}
                    </span>
                  </:cell>
                  <:cell class="py-2 align-middle text-right">
                    <% transcript_url = SessionsHelpers.transcript_download_url(session) %>
                    <% recording_url = SessionsHelpers.recording_download_url(session) %>
                    <.dropdown placement="bottom-end">
                      <:toggle>
                        <.button size="sm" variant="ghost">
                          <.icon name="hero-ellipsis-vertical" class="size-4" />
                        </.button>
                      </:toggle>
                      <.dropdown_button phx-click={
                        JS.push("open-session-sheet", value: %{id: session.id})
                      }>
                        <.icon name="hero-eye" class="icon" /> Show session details
                      </.dropdown_button>
                      <.dropdown_link
                        :if={transcript_url}
                        href={~p"/sessions/#{session.id}/transcript"}
                      >
                        <.icon name="hero-document-text" class="icon" /> Download transcript
                      </.dropdown_link>
                      <.dropdown_button :if={!transcript_url} disabled>
                        <.icon name="hero-document-text" class="icon" /> Download transcript
                      </.dropdown_button>
                      <.dropdown_link
                        :if={recording_url}
                        href={~p"/sessions/#{session.id}/recording"}
                      >
                        <.icon name="hero-play-circle" class="icon" /> Download recording
                      </.dropdown_link>
                      <.dropdown_button :if={!recording_url} disabled>
                        <.icon name="hero-play-circle" class="icon" /> Download recording
                      </.dropdown_button>
                    </.dropdown>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>
      </div>

      <.sheet
        id="session-detail-sheet"
        placement="right"
        class="w-full max-w-5xl"
        open={@session_sheet_open}
        on_close={JS.push("close-session-sheet")}
      >
        <%= if @call do %>
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
        <% end %>
      </.sheet>
    </Layouts.app>
    """
  end

  defp load_sessions(socket, opts \\ []) do
    tenant_id = socket.assigns.current_scope.tenant.id

    sessions =
      Sessions.list_sessions(
        tenant_id,
        Map.put(socket.assigns.filters, "sort", socket.assigns.sort)
      )
      |> Repo.preload([:channel, :endpoint, :agent, :customer, :artifacts])

    socket = assign(socket, :session_count, length(sessions))

    if Keyword.get(opts, :reset, false) do
      stream(socket, :sessions, sessions, reset: true)
    else
      stream(socket, :sessions, sessions)
    end
  end

  defp columns_form_map(visible_columns, allowed_columns) do
    Map.new(allowed_columns, fn column -> {column, column in visible_columns} end)
  end

  defp normalize_agent_filter(filters, agents) do
    agent_ids = MapSet.new(Enum.map(agents, &to_string(&1.id)))
    agent_id = Map.get(filters, "agent_id", "")

    if agent_id != "" and not MapSet.member?(agent_ids, to_string(agent_id)) do
      {Map.put(filters, "agent_id", ""), true}
    else
      {filters, false}
    end
  end

  defp sort_assign(sort) do
    column = Map.get(sort, "column") || Map.get(sort, :column) || "started_at"
    direction = Map.get(sort, "direction") || Map.get(sort, :direction) || "desc"

    %{column: to_string(column), direction: to_string(direction)}
  end

  defp persist_session_filters(socket, filters) do
    case Preferences.update_sessions_index_state(socket.assigns.current_scope, %{
           "filters" => filters
         }) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp persist_sort(socket, sort) do
    case Preferences.update_sessions_index_state(socket.assigns.current_scope, %{"sort" => sort}) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp filters_active?(filters) do
    query = filters |> Map.get("query", "") |> to_string() |> String.trim()

    Map.get(filters, "status") not in [nil, ""] or
      Map.get(filters, "agent_id") not in [nil, ""] or
      query != ""
  end
end
