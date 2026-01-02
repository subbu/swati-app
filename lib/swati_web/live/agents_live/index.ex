defmodule SwatiWeb.AgentsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Agents</h1>
            <p class="text-sm text-base-content/70">Design and publish voice agents.</p>
          </div>
          <.button navigate={~p"/agents/new"}>New agent</.button>
        </div>

        <.table>
          <.table_head>
            <:col>Name</:col>
            <:col>Status</:col>
            <:col>Language</:col>
            <:col>Model</:col>
            <:col></:col>
          </.table_head>
          <.table_body>
            <.table_row :for={agent <- @agents}>
              <:cell class="font-medium">{agent.name}</:cell>
              <:cell>
                <.badge color={status_color(agent.status)} variant="soft">{agent.status}</.badge>
              </:cell>
              <:cell>{agent.language}</:cell>
              <:cell class="text-xs text-base-content/60">{agent.llm_model}</:cell>
              <:cell class="text-right">
                <div class="flex items-center justify-end gap-2">
                  <.link class="text-sm underline" navigate={~p"/agents/#{agent.id}/edit"}>
                    Edit
                  </.link>
                  <.link
                    class="text-sm underline"
                    navigate={~p"/agents/#{agent.id}/versions"}
                  >
                    Versions
                  </.link>
                </div>
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

    {:ok, assign(socket, agents: agents)}
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:draft), do: "warning"
  defp status_color("draft"), do: "warning"
  defp status_color(:archived), do: "neutral"
  defp status_color("archived"), do: "neutral"
  defp status_color(_), do: "primary"
end
