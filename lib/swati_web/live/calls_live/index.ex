defmodule SwatiWeb.CallsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Calls

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-semibold">Calls</h1>
          <p class="text-sm text-base-content/70">Monitor call history and outcomes.</p>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Filters</h2>
          <.form for={@filter_form} id="calls-filter" phx-change="filter">
            <div class="grid gap-4 md:grid-cols-3">
              <.select name="filters[status]" label="Status" options={@status_options} />
              <.select name="filters[agent_id]" label="Agent" options={@agent_options} />
            </div>
          </.form>
        </section>

        <.table>
          <.table_head>
            <:col>Started</:col>
            <:col>From</:col>
            <:col>To</:col>
            <:col>Status</:col>
            <:col>Agent</:col>
            <:col></:col>
          </.table_head>
          <.table_body>
            <.table_row :for={call <- @calls}>
              <:cell>{format_datetime(call.started_at)}</:cell>
              <:cell>{call.from_number}</:cell>
              <:cell>{call.to_number}</:cell>
              <:cell>
                <.badge color={status_color(call.status)} variant="soft">{call.status}</.badge>
              </:cell>
              <:cell>{agent_name(call.agent_id, @agents)}</:cell>
              <:cell class="text-right">
                <.link class="text-sm underline" navigate={~p"/calls/#{call.id}"}>
                  View
                </.link>
              </:cell>
            </.table_row>
          </.table_body>
        </.table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    calls = Calls.list_calls(tenant.id)

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:calls, calls)
     |> assign(:filter_form, to_form(%{}, as: :filters))
     |> assign(:status_options, status_options())
     |> assign(:agent_options, agent_options(agents))}
  end

  @impl true
  def handle_event("filter", %{"filters" => filters}, socket) do
    tenant = socket.assigns.current_scope.tenant
    calls = Calls.list_calls(tenant.id, filters)

    {:noreply, assign(socket, calls: calls)}
  end

  defp status_options do
    [
      {"All", ""},
      {"Started", "started"},
      {"In progress", "in_progress"},
      {"Ended", "ended"},
      {"Failed", "failed"},
      {"Error", "error"}
    ]
  end

  defp agent_options(agents) do
    [{"All", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
  end

  defp agent_name(nil, _agents), do: "—"

  defp agent_name(agent_id, agents) do
    case Enum.find(agents, &(&1.id == agent_id)) do
      nil -> "—"
      agent -> agent.name
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M")
  end

  defp status_color(:ended), do: "success"
  defp status_color("ended"), do: "success"
  defp status_color(:failed), do: "danger"
  defp status_color("failed"), do: "danger"
  defp status_color(:error), do: "danger"
  defp status_color("error"), do: "danger"
  defp status_color(:in_progress), do: "info"
  defp status_color("in_progress"), do: "info"
  defp status_color(_), do: "neutral"
end
