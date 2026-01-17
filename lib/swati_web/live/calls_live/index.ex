defmodule SwatiWeb.CallsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Avatars
  alias Swati.Calls
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
              </.button>
              <:content>
                <div
                  class="absolute inset-px bg-base/70 items-center justify-center hidden"
                  data-loading
                >
                  <.loading class="text-foreground-softer" />
                </div>
                <h3 class="font-medium">Columns</h3>
                <.form :let={f} for={@columns_form} phx-change="update_columns">
                  <div class="flex items-center justify-between mt-3">
                    <.label for="direction" class="text-foreground">Direction</.label>
                    <.switch
                      id="direction"
                      field={f[:direction]}
                      value={@visible_columns |> Enum.member?("direction")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="started_at" class="text-foreground">Date</.label>
                    <.switch
                      id="started_at"
                      field={f[:started_at]}
                      value={@visible_columns |> Enum.member?("started_at")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="from_number" class="text-foreground">From</.label>
                    <.switch
                      id="from_number"
                      field={f[:from_number]}
                      value={@visible_columns |> Enum.member?("from_number")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="duration_seconds" class="text-foreground">Duration</.label>
                    <.switch
                      id="duration_seconds"
                      field={f[:duration_seconds]}
                      value={@visible_columns |> Enum.member?("duration_seconds")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="status" class="text-foreground">Status</.label>
                    <.switch
                      id="status"
                      field={f[:status]}
                      value={@visible_columns |> Enum.member?("status")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="agent_id" class="text-foreground">Agent</.label>
                    <.switch
                      id="agent_id"
                      field={f[:agent_id]}
                      value={@visible_columns |> Enum.member?("agent_id")}
                    />
                  </div>
                </.form>
              </:content>
            </.popover>
          </div>

          <div class="overflow-x-auto">
            <.table>
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col :if={"direction" in @visible_columns} class="py-2">Direction</:col>
                <:col
                  :if={"started_at" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="started_at"
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
                    <span class="font-medium text-foreground">
                      {CallsHelpers.format_phone(call.from_number, @current_scope.tenant)}
                    </span>
                  </:cell>
                  <:cell :if={"duration_seconds" in @visible_columns} class="py-2 align-middle">
                    {CallsHelpers.format_duration(call)}
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
                    <.button
                      size="sm"
                      variant="ghost"
                      phx-click={JS.push("open-call-sheet", value: %{id: call.id})}
                    >
                      View
                    </.button>
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

    avatars_by_agent =
      Avatars.latest_avatars_by_agent(socket.assigns.current_scope, agent_ids(agents))

    phone_numbers = Telephony.list_phone_numbers(tenant.id)
    phone_number_e164s = MapSet.new(Enum.map(phone_numbers, & &1.e164))
    filters = %{"status" => "", "agent_id" => "", "query" => ""}
    sort = %{column: "started_at", direction: "desc"}

    visible_columns = ~w(direction started_at from_number duration_seconds status agent_id)

    calls = Calls.list_calls(tenant.id, Map.put(filters, "sort", sort))

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:avatars_by_agent, avatars_by_agent)
     |> assign(:phone_number_e164s, phone_number_e164s)
     |> assign(:calls, calls)
     |> assign(:filters, filters)
     |> assign(:visible_columns, visible_columns)
     |> assign(
       :columns_form,
       to_form(%{
         "direction" => true,
         "started_at" => true,
         "from_number" => true,
         "duration_seconds" => true,
         "status" => true,
         "agent_id" => true
       })
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

    {:noreply,
     socket
     |> assign(:calls, calls)
     |> assign(:filters, merged_filters)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    tenant = socket.assigns.current_scope.tenant
    sort = CallsHelpers.next_sort(socket.assigns.sort, column)
    calls = Calls.list_calls(tenant.id, Map.put(socket.assigns.filters, "sort", sort))

    {:noreply,
     socket
     |> assign(:calls, calls)
     |> assign(:sort, sort)}
  end

  @impl true
  def handle_event("update_columns", columns, socket) do
    visible_columns =
      columns
      |> Map.keys()
      |> Enum.filter(&Phoenix.HTML.Form.normalize_value("checkbox", columns[&1]))

    {:noreply, assign(socket, columns_form: to_form(columns), visible_columns: visible_columns)}
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
end
