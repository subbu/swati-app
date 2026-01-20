defmodule SwatiWeb.CasesLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Cases
  alias Swati.Preferences
  alias Swati.Repo
  alias SwatiWeb.CasesLive.Helpers, as: CasesHelpers

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    view_state = Preferences.cases_index_state(socket.assigns.current_scope)
    allowed_columns = Preferences.cases_index_columns()
    default_sort = Map.get(Preferences.cases_index_defaults(), "sort", %{})

    filters =
      %{"status" => "", "assigned_agent_id" => "", "query" => ""}
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
      |> assign(:status_options, CasesHelpers.status_options())
      |> assign(:agent_options, CasesHelpers.agent_options(agents))
      |> assign(:sort, sort)
      |> assign(:visible_columns, visible_columns)
      |> assign(:hidden_columns_count, hidden_columns_count)
      |> assign(
        :columns_form,
        visible_columns
        |> columns_form_map(allowed_columns)
        |> to_form()
      )

    _ =
      if filters_changed? do
        persist_case_filters(socket, filters)
      else
        :ok
      end

    {:ok, load_cases(socket)}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    merged_filters = Map.merge(socket.assigns.filters, filters)
    filters_active = filters_active?(merged_filters)

    if merged_filters != socket.assigns.filters do
      persist_case_filters(socket, merged_filters)
    end

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, filters_active)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> load_cases(reset: true)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    default_filters = Map.get(Preferences.cases_index_defaults(), "filters", %{})
    merged_filters = Map.merge(socket.assigns.filters, default_filters)

    persist_case_filters(socket, default_filters)

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> load_cases(reset: true)}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    sort = CasesHelpers.next_sort(socket.assigns.sort, column)
    persist_sort(socket, sort)

    {:noreply,
     socket
     |> assign(:sort, sort)
     |> load_cases(reset: true)}
  end

  @impl true
  def handle_event("update_columns", columns, socket) do
    allowed_columns = Preferences.cases_index_columns()

    visible_columns =
      Enum.filter(allowed_columns, fn column ->
        Phoenix.HTML.Form.normalize_value("checkbox", Map.get(columns, column))
      end)

    hidden_columns_count = max(length(allowed_columns) - length(visible_columns), 0)

    if visible_columns != socket.assigns.visible_columns do
      _ =
        Preferences.update_cases_index_state(socket.assigns.current_scope, %{
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
    default_columns = Preferences.cases_index_columns()
    hidden_columns_count = 0

    _ =
      Preferences.update_cases_index_state(socket.assigns.current_scope, %{
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
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-amber-400 to-amber-600 text-white shadow">
              <.icon name="hero-briefcase" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Cases</h1>
              <p class="text-sm text-foreground-soft">Case-centric timeline across sessions.</p>
            </div>
          </div>
          <div class="ml-auto flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{@case_count}</span>
            <span>cases</span>
          </div>
        </header>

        <section class="rounded-base bg-base overflow-hidden">
          <div class="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-base">
            <.form
              for={@filter_form}
              id="cases-filter"
              phx-change="filter"
              class="flex items-center gap-2"
            >
              <.input
                field={@filter_form[:query]}
                type="text"
                placeholder="Search cases"
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
                    {CasesHelpers.status_filter_label(@filters)}
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
                    {CasesHelpers.agent_filter_label(@filters, @agents)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={
                JS.push("filter", value: %{filters: %{"assigned_agent_id" => ""}})
              }>
                All agents
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- @agent_options |> Enum.reject(&(elem(&1, 1) == ""))}
                phx-click={JS.push("filter", value: %{filters: %{"assigned_agent_id" => value}})}
              >
                {label}
              </.dropdown_button>
            </.dropdown>

            <.popover
              id="cases-columns-popover"
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
                <.form for={@columns_form} id="cases-columns-form" phx-change="update_columns">
                  <div class="flex items-center justify-between mt-3">
                    <.label for="case" class="text-foreground">Case</.label>
                    <.switch
                      id="case"
                      field={@columns_form[:case]}
                      value={@visible_columns |> Enum.member?("case")}
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
                    <.label for="priority" class="text-foreground">Priority</.label>
                    <.switch
                      id="priority"
                      field={@columns_form[:priority]}
                      value={@visible_columns |> Enum.member?("priority")}
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
                    <.label for="assigned_agent" class="text-foreground">Agent</.label>
                    <.switch
                      id="assigned_agent"
                      field={@columns_form[:assigned_agent]}
                      value={@visible_columns |> Enum.member?("assigned_agent")}
                    />
                  </div>
                  <div class="flex items-center justify-between mt-3">
                    <.label for="updated_at" class="text-foreground">Updated</.label>
                    <.switch
                      id="updated_at"
                      field={@columns_form[:updated_at]}
                      value={@visible_columns |> Enum.member?("updated_at")}
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
            <.table id="cases-table">
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col :if={"case" in @visible_columns} class="py-2" data-column="case">
                  Case
                </:col>
                <:col
                  :if={"status" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="status"
                  data-column="status"
                >
                  <button type="button" class={CasesHelpers.sort_button_class("status", @sort)}>
                    Status <CasesHelpers.sort_icon column="status" sort={@sort} />
                  </button>
                </:col>
                <:col
                  :if={"priority" in @visible_columns}
                  class="py-2"
                  phx-click="sort"
                  phx-value-column="priority"
                  data-column="priority"
                >
                  <button type="button" class={CasesHelpers.sort_button_class("priority", @sort)}>
                    Priority <CasesHelpers.sort_icon column="priority" sort={@sort} />
                  </button>
                </:col>
                <:col :if={"customer" in @visible_columns} class="py-2" data-column="customer">
                  Customer
                </:col>
                <:col :if={"assigned_agent" in @visible_columns} class="py-2" data-column="agent">
                  Agent
                </:col>
                <:col
                  :if={"updated_at" in @visible_columns}
                  class="py-2 w-full"
                  phx-click="sort"
                  phx-value-column="updated_at"
                  data-column="updated_at"
                >
                  <button type="button" class={CasesHelpers.sort_button_class("updated_at", @sort)}>
                    Updated <CasesHelpers.sort_icon column="updated_at" sort={@sort} />
                  </button>
                </:col>
              </.table_head>
              <.table_body id="cases" phx-update="stream" class="text-foreground-soft">
                <.table_row
                  :for={{id, case_record} <- @streams.cases}
                  id={id}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell :if={"case" in @visible_columns} class="py-2 align-middle">
                    <.link navigate={~p"/cases/#{case_record.id}"} class="text-foreground font-medium">
                      {case_record.title || "Untitled case"}
                    </.link>
                    <div class="text-xs text-foreground-softest">
                      {case_record.category || "General"}
                    </div>
                  </:cell>
                  <:cell :if={"status" in @visible_columns} class="py-2 align-middle">
                    <% badge = CasesHelpers.status_badge(case_record.status) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell :if={"priority" in @visible_columns} class="py-2 align-middle">
                    <% badge = CasesHelpers.priority_badge(case_record.priority) %>
                    <.badge size="sm" variant="soft" color={badge.color}>{badge.label}</.badge>
                  </:cell>
                  <:cell :if={"customer" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {CasesHelpers.customer_name(case_record)}
                    </span>
                  </:cell>
                  <:cell :if={"assigned_agent" in @visible_columns} class="py-2 align-middle">
                    <span class="text-foreground font-medium">
                      {CasesHelpers.assigned_agent_name(case_record)}
                    </span>
                  </:cell>
                  <:cell :if={"updated_at" in @visible_columns} class="py-2 align-middle">
                    <div class="flex flex-col">
                      <span class="text-foreground font-medium">
                        {CasesHelpers.format_relative(case_record.updated_at, @current_scope.tenant)}
                      </span>
                      <span class="text-xs text-foreground-softest">
                        {CasesHelpers.format_datetime(case_record.updated_at, @current_scope.tenant)}
                      </span>
                    </div>
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

  defp load_cases(socket, opts \\ []) do
    tenant_id = socket.assigns.current_scope.tenant.id

    cases =
      Cases.list_cases(
        tenant_id,
        Map.put(socket.assigns.filters, "sort", socket.assigns.sort)
      )
      |> Repo.preload([:customer, :assigned_agent])

    socket = assign(socket, :case_count, length(cases))

    if Keyword.get(opts, :reset, false) do
      stream(socket, :cases, cases, reset: true)
    else
      stream(socket, :cases, cases)
    end
  end

  defp columns_form_map(visible_columns, allowed_columns) do
    Map.new(allowed_columns, fn column -> {column, column in visible_columns} end)
  end

  defp normalize_agent_filter(filters, agents) do
    agent_ids = MapSet.new(Enum.map(agents, &to_string(&1.id)))
    agent_id = Map.get(filters, "assigned_agent_id", "")

    if agent_id != "" and not MapSet.member?(agent_ids, to_string(agent_id)) do
      {Map.put(filters, "assigned_agent_id", ""), true}
    else
      {filters, false}
    end
  end

  defp sort_assign(sort) do
    column = Map.get(sort, "column") || Map.get(sort, :column) || "updated_at"
    direction = Map.get(sort, "direction") || Map.get(sort, :direction) || "desc"

    %{column: to_string(column), direction: to_string(direction)}
  end

  defp persist_case_filters(socket, filters) do
    case Preferences.update_cases_index_state(socket.assigns.current_scope, %{
           "filters" => filters
         }) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp persist_sort(socket, sort) do
    case Preferences.update_cases_index_state(socket.assigns.current_scope, %{"sort" => sort}) do
      {:ok, _preference} -> :ok
      {:error, _reason} -> :ok
    end
  end

  defp filters_active?(filters) do
    query = filters |> Map.get("query", "") |> to_string() |> String.trim()

    Map.get(filters, "status") not in [nil, ""] or
      Map.get(filters, "assigned_agent_id") not in [nil, ""] or
      query != ""
  end
end
