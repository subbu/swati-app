defmodule SwatiWeb.AgentsLive.Versions do
  use SwatiWeb, :live_view

  alias Swati.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Agent versions</h1>
            <p class="text-sm text-base-content/70">{assigns.agent.name}</p>
          </div>
          <.button navigate={~p"/agents"} variant="ghost">Back</.button>
        </div>

        <.table>
          <.table_head>
            <:col>Version</:col>
            <:col>Published at</:col>
            <:col>Config size</:col>
          </.table_head>
          <.table_body>
            <.table_row :for={version <- @versions}>
              <:cell>v{version.version}</:cell>
              <:cell>{format_datetime(version.published_at)}</:cell>
              <:cell class="text-xs text-base-content/60">
                {map_size(version.config || %{})} keys
              </:cell>
            </.table_row>
          </.table_body>
        </.table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    agent = Agents.get_agent!(socket.assigns.current_scope.tenant.id, id)
    versions = Agents.list_agent_versions(agent.id)

    {:ok, assign(socket, agent: agent, versions: versions)}
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M")
  end
end
