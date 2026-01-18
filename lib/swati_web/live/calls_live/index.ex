defmodule SwatiWeb.CallsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Avatars
  alias Swati.Calls
  alias Swati.Preferences
  alias Swati.Telephony
  alias SwatiWeb.CallsLive.Helpers, as: CallsHelpers
  alias SwatiWeb.CallsLive.Show, as: CallsShow

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-blue-500 to-blue-600 text-white shadow">
              <.icon name="hero-phone" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Calls</h1>
              <p class="text-sm text-foreground-soft">Monitor call history and outcomes.</p>
            </div>
          </div>
          <div class="ml-auto flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{length(@calls)}</span>
            <span>total calls</span>
          </div>
        </header>

        <section class="rounded-base bg-base overflow-hidden">
          <div class="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-base">
            <.form
              for={@filter_form}
              id="calls-filter"
              phx-change="filter"
              class="flex items-center gap-2"
            >
              <.input
                field={@filter_form[:query]}
                type="text"
                placeholder="Search numbers"
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
                    {CallsHelpers.status_filter_label(@filters)}
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
                    {CallsHelpers.agent_filter_label(@filters, @agents)}
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
              id="columns-popover"
              placement="bottom-start"
              class="min-w-52 [&:has(.phx-change-loading)_[data-loading]]:flex"
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
                <.form for={@columns_form} id="calls-columns-form" phx-change="update_columns">
                  <div class="flex items-center justify-between mt-3">
                    <.label for="direction" class="text-foreground">Direction</.label>
                    <.switch
                      id="direction"
                      field={@columns_form[:direction]}
                      value={@visible_columns |> Enum.member?("direction")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="started_at" class="text-foreground">Date</.label>
                    <.switch
                      id="started_at"
                      field={@columns_form[:started_at]}
                      value={@visible_columns |> Enum.member?("started_at")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="from_number" class="text-foreground">From</.label>
                    <.switch
                      id="from_number"
                      field={@columns_form[:from_number]}
                      value={@visible_columns |> Enum.member?("from_number")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="duration_seconds" class="text-foreground">Duration</.label>
                    <.switch
                      id="duration_seconds"
                      field={@columns_form[:duration_seconds]}
                      value={@visible_columns |> Enum.member?("duration_seconds")}
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
                    <.label for="agent_id" class="text-foreground">Agent</.label>
                    <.switch
                      id="agent_id"
                      field={@columns_form[:agent_id]}
                      value={@visible_columns |> Enum.member?("agent_id")}
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
            <.table id="calls-table">
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col :if={"direction" in @visible_columns} class="py-2" data-column="direction">
                  Direction
                </:col>
                <:col
                  :if={"started_at" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="started_at"
                  data-column="started_at"
                >
                  <button type="button" class={CallsHelpers.sort_button_class("started_at", @sort)}>
                    Date <CallsHelpers.sort_icon column="started_at" sort={@sort} />
                  </button>
                </:col>
                <:col
                  :if={"from_number" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="from_number"
                  data-column="from_number"
                >
                  <button type="button" class={CallsHelpers.sort_button_class("from_number", @sort)}>
                    From <CallsHelpers.sort_icon column="from_number" sort={@sort} />
                  </button>
                </:col>
                <:col
                  :if={"duration_seconds" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="duration_seconds"
                  data-column="duration_seconds"
                >
                  <button
                    type="button"
                    class={CallsHelpers.sort_button_class("duration_seconds", @sort)}
                  >
                    Duration <CallsHelpers.sort_icon column="duration_seconds" sort={@sort} />
                  </button>
                </:col>
                <:col
                  :if={"status" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="status"
                  data-column="status"
                >
                  <button type="button" class={CallsHelpers.sort_button_class("status", @sort)}>
                    Status <CallsHelpers.sort_icon column="status" sort={@sort} />
                  </button>
                </:col>
                <:col
                  :if={"agent_id" in @visible_columns}
                  class="py-2 w-full"
                  phx-click="sort"
                  phx-value-column="agent_id"
                  data-column="agent_id"
                >
                  <button type="button" class={CallsHelpers.sort_button_class("agent_id", @sort)}>
                    Agent <CallsHelpers.sort_icon column="agent_id" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2 pr-4 text-right"></:col>
              </.table_head>
              <.table_body class="text-foreground-soft">
                <.table_row
                  :for={call <- @calls}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell :if={"direction" in @visible_columns} class="py-2 align-middle">
                    <% direction = CallsHelpers.direction_display(call, @phone_number_e164s) %>
                    <span class="inline-flex items-center">
                      <.icon name={direction.icon_name} class={"size-4 #{direction.icon_class}"} />
                      <span class="sr-only">{direction.label}</span>
                    </span>
                  </:cell>
                  <:cell :if={"started_at" in @visible_columns} class="py-2 align-middle">
                    <% started_at =
                      CallsHelpers.format_datetime(call.started_at, @current_scope.tenant) %>
                    <% age = CallsHelpers.format_relative(call.started_at, @current_scope.tenant) %>
                    <div class="flex items-center justify-between gap-3">
                      <div class="flex flex-col gap-0.5">
                        <span class="text-foreground font-medium">{age}</span>
                        <span class="text-foreground-softest text-xs">{started_at}</span>
                      </div>
                      <.icon
                        name="hero-chevron-right"
                        class="size-4 text-foreground-softer opacity-0 group-hover:opacity-100"
                      />
                    </div>
                  </:cell>
                  <:cell :if={"from_number" in @visible_columns} class="py-2 align-middle">
                    <.button
                      size="sm"
                      variant="ghost"
                      class="h-auto p-0 text-foreground font-medium hover:text-foreground"
                      phx-click={JS.push("open-call-sheet", value: %{id: call.id})}
                    >
                      {CallsHelpers.format_phone(call.from_number, @current_scope.tenant)}
                    </.button>
                  </:cell>
                  <:cell :if={"duration_seconds" in @visible_columns} class="py-2 align-middle">
                    <% duration_seconds = CallsHelpers.call_duration_seconds(call) %>
                    <% max_duration = @max_duration_seconds %>
                    <% bar_percent =
                      if is_integer(duration_seconds) and is_integer(max_duration) and
                           max_duration > 0 do
                        min(div(duration_seconds * 100, max_duration), 100)
                      else
                        0
                      end %>
                    <div class="flex flex-col gap-1.5">
                      <span class="font-medium text-foreground tabular-nums">
                        {CallsHelpers.format_duration(call)}
                      </span>
                      <div class="h-1.5 w-24 rounded-full bg-foreground/10 overflow-hidden">
                        <div
                          class={[
                            "h-full rounded-full transition-all",
                            CallsHelpers.duration_bar_class(call.status)
                          ]}
                          style={"width: #{bar_percent}%"}
                        >
                        </div>
                      </div>
                    </div>
                  </:cell>
                  <:cell :if={"status" in @visible_columns} class="py-2 align-middle">
                    <% status_info = CallsHelpers.status_display(call.status) %>
                    <div class="flex items-center gap-x-2">
                      <.icon name={status_info.icon_name} class={"size-5 #{status_info.icon_class}"} />
                      <span>{status_info.label}</span>
                    </div>
                  </:cell>
                  <:cell :if={"agent_id" in @visible_columns} class="py-2 align-middle w-full">
                    <% agent = CallsHelpers.agent_display(call.agent_id, @agents) %>
                    <% to_number = CallsHelpers.format_phone(call.to_number, @current_scope.tenant) %>
                    <% avatar_url =
                      CallsHelpers.agent_avatar_url(
                        @avatars_by_agent,
                        call.agent_id,
                        agent.name
                      ) %>
                    <div class="flex items-center gap-3">
                      <img src={avatar_url} class="size-9 rounded-full" alt="" loading="lazy" />
                      <div class="flex flex-col gap-0.5">
                        <span class="font-semibold text-foreground">{agent.name}</span>
                        <span class="text-foreground-softest text-xs">{to_number}</span>
                      </div>
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle text-right">
                    <% transcript_url = CallsHelpers.transcript_download_url(call) %>
                    <% recording_url = CallsHelpers.recording_download_url(call) %>
                    <.dropdown placement="bottom-end">
                      <:toggle>
                        <.button size="sm" variant="ghost">
                          <.icon name="hero-ellipsis-vertical" class="size-4" />
                        </.button>
                      </:toggle>
                      <.dropdown_button phx-click={JS.push("open-call-sheet", value: %{id: call.id})}>
                        Show call details
                      </.dropdown_button>
                      <.dropdown_link
                        :if={transcript_url}
                        href={~p"/calls/#{call.id}/transcript"}
                      >
                        Download transcript
                      </.dropdown_link>
                      <.dropdown_button :if={!transcript_url} disabled>
                        Download transcript
                      </.dropdown_button>
                      <.dropdown_link
                        :if={recording_url}
                        href={~p"/calls/#{call.id}/recording"}
                      >
                        Download recording
                      </.dropdown_link>
                      <.dropdown_button :if={!recording_url} disabled>
                        Download recording
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
        id="call-detail-sheet"
        placement="right"
        class="w-full max-w-5xl"
        open={@call_sheet_open}
        on_close={JS.push("close-call-sheet")}
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
            back_patch={~p"/calls"}
          />
        <% end %>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    view_state = Preferences.calls_index_state(socket.assigns.current_scope)
    allowed_columns = Preferences.calls_index_columns()
    default_sort = Map.get(Preferences.calls_index_defaults(), "sort", %{})

    avatars_by_agent =
      Avatars.latest_avatars_by_agent(socket.assigns.current_scope, agent_ids(agents))

    phone_numbers = Telephony.list_phone_numbers(tenant.id)
    phone_number_e164s = MapSet.new(Enum.map(phone_numbers, & &1.e164))

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

    calls = Calls.list_calls(tenant.id, Map.put(filters, "sort", sort))

    if filters_changed? do
      persist_call_filters(socket, Map.take(filters, ["status", "agent_id"]))
    end

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:avatars_by_agent, avatars_by_agent)
     |> assign(:phone_number_e164s, phone_number_e164s)
     |> assign_calls(calls)
     |> assign(:filters, filters)
     |> assign(:filters_active, filters_active)
     |> assign(:visible_columns, visible_columns)
     |> assign(:hidden_columns_count, hidden_columns_count)
     |> assign(
       :columns_form,
       visible_columns
       |> columns_form_map(allowed_columns)
       |> to_form()
     )
     |> assign(:sort, sort)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:status_options, CallsHelpers.status_options())
     |> assign(:agent_options, CallsHelpers.agent_options(agents))
     |> assign(:call_sheet_open, false)
     |> assign(:call, nil)}
  end

  defp agent_ids(agents), do: Enum.map(agents, & &1.id)

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    tenant = socket.assigns.current_scope.tenant
    call_id = CallsHelpers.parse_id(id)

    if is_nil(call_id) do
      {:noreply, push_patch(socket, to: ~p"/calls")}
    else
      call = Calls.get_call!(tenant.id, call_id)
      timeline = Calls.get_call_timeline(tenant.id, call_id)

      {:noreply,
       socket
       |> assign(CallsShow.detail_assigns(call, timeline))
       |> assign(call_sheet_open: true)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, call_sheet_open: false, call: nil)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    tenant = socket.assigns.current_scope.tenant
    merged_filters = Map.merge(socket.assigns.filters, filters)
    calls = Calls.list_calls(tenant.id, Map.put(merged_filters, "sort", socket.assigns.sort))
    allowed_filters = Map.take(merged_filters, ["status", "agent_id"])
    filters_active = filters_active?(merged_filters)

    if allowed_filters != Map.take(socket.assigns.filters, ["status", "agent_id"]) do
      persist_call_filters(socket, allowed_filters)
    end

    {:noreply,
     socket
     |> assign_calls(calls)
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, filters_active)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    tenant = socket.assigns.current_scope.tenant
    sort = CallsHelpers.next_sort(socket.assigns.sort, column)
    calls = Calls.list_calls(tenant.id, Map.put(socket.assigns.filters, "sort", sort))
    persist_sort(socket, sort)

    {:noreply,
     socket
     |> assign_calls(calls)
     |> assign(:sort, sort)}
  end

  @impl true
  def handle_event("update_columns", columns, socket) do
    allowed_columns = Preferences.calls_index_columns()

    visible_columns =
      Enum.filter(allowed_columns, fn column ->
        Phoenix.HTML.Form.normalize_value("checkbox", Map.get(columns, column))
      end)

    hidden_columns_count = max(length(allowed_columns) - length(visible_columns), 0)

    if visible_columns != socket.assigns.visible_columns do
      _ =
        Preferences.update_calls_index_state(socket.assigns.current_scope, %{
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
    default_columns = Preferences.calls_index_columns()
    hidden_columns_count = 0

    _ =
      Preferences.update_calls_index_state(socket.assigns.current_scope, %{
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
  def handle_event("reset_filters", _params, socket) do
    default_filters = Map.get(Preferences.calls_index_defaults(), "filters", %{})

    merged_filters =
      socket.assigns.filters
      |> Map.merge(default_filters)

    calls =
      Calls.list_calls(
        socket.assigns.current_scope.tenant.id,
        Map.put(merged_filters, "sort", socket.assigns.sort)
      )

    persist_call_filters(socket, default_filters)

    {:noreply,
     socket
     |> assign_calls(calls)
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))}
  end

  @impl true
  def handle_event("open-call-sheet", %{"id" => id}, socket) do
    call_id = CallsHelpers.parse_id(id)

    if is_nil(call_id) do
      {:noreply, socket}
    else
      {:noreply, push_patch(socket, to: ~p"/calls/#{call_id}")}
    end
  end

  @impl true
  def handle_event("close-call-sheet", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/calls")}
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

  defp persist_call_filters(socket, filters) do
    case Preferences.update_calls_index_state(socket.assigns.current_scope, %{
           "filters" => filters
         }) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp persist_sort(socket, sort) do
    case Preferences.update_calls_index_state(socket.assigns.current_scope, %{
           "sort" => sort
         }) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp filters_active?(filters) do
    Map.get(filters, "status") not in [nil, ""] or
      Map.get(filters, "agent_id") not in [nil, ""]
  end

  defp assign_calls(socket, calls) do
    assign(socket, calls: calls, max_duration_seconds: max_duration_seconds(calls))
  end

  defp max_duration_seconds(calls) do
    calls
    |> Enum.map(&CallsHelpers.call_duration_seconds/1)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> 0
      durations -> Enum.max(durations)
    end
  end
end
