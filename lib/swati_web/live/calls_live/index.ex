defmodule SwatiWeb.CallsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Calls

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

        <section class="rounded-base border border-base bg-base overflow-hidden">
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
                  <span class="hidden lg:inline ml-1">{status_filter_label(@filters)}</span>
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
                  <span class="hidden lg:inline ml-1">{agent_filter_label(@filters, @agents)}</span>
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
          </div>

          <div class="overflow-x-auto">
            <.table>
              <.table_head class="text-foreground-soft [&_th:first-child]:pl-4!">
                <:col class="py-2" phx-click="sort" phx-value-column="started_at">
                  <button type="button" class={sort_button_class("started_at", @sort)}>
                    Started <.sort_icon column="started_at" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2" phx-click="sort" phx-value-column="from_number">
                  <button type="button" class={sort_button_class("from_number", @sort)}>
                    From <.sort_icon column="from_number" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2" phx-click="sort" phx-value-column="to_number">
                  <button type="button" class={sort_button_class("to_number", @sort)}>
                    To <.sort_icon column="to_number" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2" phx-click="sort" phx-value-column="duration_seconds">
                  <button type="button" class={sort_button_class("duration_seconds", @sort)}>
                    Duration <.sort_icon column="duration_seconds" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2" phx-click="sort" phx-value-column="status">
                  <button type="button" class={sort_button_class("status", @sort)}>
                    Status <.sort_icon column="status" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2" phx-click="sort" phx-value-column="agent_id">
                  <button type="button" class={sort_button_class("agent_id", @sort)}>
                    Agent <.sort_icon column="agent_id" sort={@sort} />
                  </button>
                </:col>
                <:col class="py-2 pr-4 text-right"></:col>
              </.table_head>
              <.table_body class="text-foreground-soft">
                <.table_row
                  :for={call <- @calls}
                  class="[&_td:first-child]:pl-4! [&_td:last-child]:pr-4! hover:bg-accent/50 transition-colors group"
                >
                  <:cell class="py-2 align-middle">
                    <div class="flex items-center">
                      <span class="text-foreground">{format_datetime(call.started_at)}</span>
                      <.icon
                        name="hero-chevron-right"
                        class="ml-auto size-4 text-foreground-softer opacity-0 group-hover:opacity-100"
                      />
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="font-medium text-foreground">{format_phone(call.from_number)}</span>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <span class="font-medium text-foreground">{format_phone(call.to_number)}</span>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    {format_duration(call)}
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <% status_info = status_display(call.status) %>
                    <div class="flex items-center gap-x-2">
                      <.icon name={status_info.icon_name} class={"size-5 #{status_info.icon_class}"} />
                      <span>{status_info.label}</span>
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle">
                    <% agent = agent_display(call.agent_id, @agents) %>
                    <div class="flex items-center gap-2">
                      <div class={"size-6 rounded-full text-xs font-semibold flex items-center justify-center #{agent.color}"}>
                        {agent.initial}
                      </div>
                      <span class="font-medium text-foreground">{agent.name}</span>
                    </div>
                  </:cell>
                  <:cell class="py-2 align-middle text-right">
                    <.button size="sm" variant="ghost" navigate={~p"/calls/#{call.id}"}>
                      View
                    </.button>
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

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    filters = %{"status" => "", "agent_id" => "", "query" => ""}
    sort = %{column: "started_at", direction: "desc"}
    calls = Calls.list_calls(tenant.id, Map.put(filters, "sort", sort))

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:calls, calls)
     |> assign(:filters, filters)
     |> assign(:sort, sort)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:status_options, status_options())
     |> assign(:agent_options, agent_options(agents))}
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
    sort = next_sort(socket.assigns.sort, column)
    calls = Calls.list_calls(tenant.id, Map.put(socket.assigns.filters, "sort", sort))

    {:noreply,
     socket
     |> assign(:calls, calls)
     |> assign(:sort, sort)}
  end

  defp status_options do
    [
      {"All", ""},
      {"Started", "started"},
      {"In progress", "in_progress"},
      {"Ended", "ended"},
      {"Failed", "failed"},
      {"Cancelled", "cancelled"},
      {"Error", "error"}
    ]
  end

  defp agent_options(agents) do
    [{"All", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M")
  end

  defp format_phone(nil), do: "—"
  defp format_phone(""), do: "—"
  defp format_phone(number), do: number

  defp format_duration(call) do
    seconds = call_duration_seconds(call)

    cond do
      is_nil(seconds) -> "—"
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m #{rem(seconds, 60)}s"
    end
  end

  defp call_duration_seconds(%{duration_seconds: duration}) when is_integer(duration),
    do: duration

  defp call_duration_seconds(%{
         started_at: %DateTime{} = started_at,
         ended_at: %DateTime{} = ended_at
       }) do
    max(DateTime.diff(ended_at, started_at, :second), 0)
  end

  defp call_duration_seconds(_call), do: nil

  defp agent_display(agent_id, agents) do
    case Enum.find(agents, &(&1.id == agent_id)) do
      nil ->
        %{name: "Unassigned", initial: "—", color: "bg-zinc-200/70 text-zinc-600"}

      agent ->
        %{name: agent.name, initial: String.first(agent.name), color: avatar_color(agent.name)}
    end
  end

  defp avatar_color(name) do
    colors = [
      "bg-red-200/60 text-red-900",
      "bg-blue-200/60 text-blue-900",
      "bg-green-200/60 text-green-900",
      "bg-yellow-200/60 text-yellow-900",
      "bg-purple-200/60 text-purple-900",
      "bg-pink-200/60 text-pink-900",
      "bg-indigo-200/60 text-indigo-900",
      "bg-teal-200/60 text-teal-900"
    ]

    index = :erlang.phash2(name) |> rem(length(colors))
    Enum.at(colors, index)
  end

  defp status_filter_label(filters) do
    case Map.get(filters, "status") do
      nil -> "Status"
      "" -> "Status"
      status -> status_display(status).label
    end
  end

  defp agent_filter_label(filters, agents) do
    case Map.get(filters, "agent_id") do
      nil ->
        "Agent"

      "" ->
        "Agent"

      agent_id ->
        case Enum.find(agents, &(to_string(&1.id) == to_string(agent_id))) do
          nil -> "Agent"
          agent -> agent.name
        end
    end
  end

  attr :column, :string, required: true
  attr :sort, :map, required: true

  defp sort_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 16 16"
      class={["size-4", sort_icon_class(@column, @sort)]}
    >
      <path fill="currentColor" d="M11 7H5l3-4z" />
      <path fill="currentColor" d="M5 9h6l-3 4z" />
    </svg>
    """
  end

  defp sort_button_class(column, %{column: column}),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground"

  defp sort_button_class(_column, _sort),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground-soft"

  defp sort_icon_class(column, %{column: column}), do: "text-foreground"
  defp sort_icon_class(_column, _sort), do: "text-foreground-softest"

  defp next_sort(%{column: column, direction: direction}, column),
    do: %{column: column, direction: toggle_sort_direction(direction)}

  defp next_sort(_sort, column),
    do: %{column: column, direction: default_sort_direction(column)}

  defp toggle_sort_direction("asc"), do: "desc"
  defp toggle_sort_direction(_direction), do: "asc"

  defp default_sort_direction("started_at"), do: "desc"
  defp default_sort_direction("duration_seconds"), do: "desc"
  defp default_sort_direction(_column), do: "asc"

  defp status_display(status) do
    case status do
      :ended ->
        %{label: "Ended", icon_name: "hero-check-circle", icon_class: "text-emerald-500"}

      "ended" ->
        %{label: "Ended", icon_name: "hero-check-circle", icon_class: "text-emerald-500"}

      :failed ->
        %{label: "Failed", icon_name: "hero-x-circle", icon_class: "text-rose-500"}

      "failed" ->
        %{label: "Failed", icon_name: "hero-x-circle", icon_class: "text-rose-500"}

      :error ->
        %{label: "Error", icon_name: "hero-exclamation-triangle", icon_class: "text-amber-500"}

      "error" ->
        %{label: "Error", icon_name: "hero-exclamation-triangle", icon_class: "text-amber-500"}

      :in_progress ->
        %{label: "In progress", icon_name: "hero-arrow-path", icon_class: "text-blue-500"}

      "in_progress" ->
        %{label: "In progress", icon_name: "hero-arrow-path", icon_class: "text-blue-500"}

      :cancelled ->
        %{label: "Cancelled", icon_name: "hero-signal-slash", icon_class: "text-zinc-500"}

      "cancelled" ->
        %{label: "Cancelled", icon_name: "hero-signal-slash", icon_class: "text-zinc-500"}

      :started ->
        %{label: "Started", icon_name: "hero-play-circle", icon_class: "text-foreground-softer"}

      "started" ->
        %{label: "Started", icon_name: "hero-play-circle", icon_class: "text-foreground-softer"}

      _ ->
        %{
          label: "Unknown",
          icon_name: "hero-question-mark-circle",
          icon_class: "text-foreground-softer"
        }
    end
  end
end
