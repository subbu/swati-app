defmodule SwatiWeb.AgentsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Avatars

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
            <:col>Agent</:col>
            <:col>Status</:col>
            <:col>Language</:col>
            <:col>Model</:col>
            <:col></:col>
          </.table_head>
          <.table_body>
            <.table_row :for={agent <- @agents}>
              <:cell>
                <div class="flex items-center gap-3">
                  <div class="size-10 overflow-hidden rounded-full border border-base-300 bg-base-200">
                    <%= if avatar_ready?(@avatars_by_agent, agent.id) do %>
                      <img
                        class="size-full object-cover"
                        src={@avatars_by_agent[agent.id].output_url}
                        alt=""
                        loading="lazy"
                      />
                    <% else %>
                      <span class="flex size-full items-center justify-center text-sm font-semibold text-base-content/70">
                        {initials(agent.name)}
                      </span>
                    <% end %>
                  </div>
                  <div>
                    <p class="font-medium">{agent.name}</p>
                    <p class="text-xs text-base-content/60">
                      {avatar_status_label(@avatars_by_agent, agent.id)}
                    </p>
                  </div>
                </div>
              </:cell>
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

    avatars_by_agent =
      Avatars.latest_avatars_by_agent(socket.assigns.current_scope, agent_ids(agents))

    {:ok, assign(socket, agents: agents, avatars_by_agent: avatars_by_agent)}
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:draft), do: "warning"
  defp status_color("draft"), do: "warning"
  defp status_color(:archived), do: "neutral"
  defp status_color("archived"), do: "neutral"
  defp status_color(_), do: "primary"

  defp agent_ids(agents), do: Enum.map(agents, & &1.id)

  defp initials(nil), do: "?"

  defp initials(name) when is_binary(name) do
    name
    |> String.split(~r/\\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp avatar_ready?(avatars_by_agent, agent_id) do
    case Map.get(avatars_by_agent, agent_id) do
      %{status: :ready, output_url: url} when is_binary(url) -> true
      _ -> false
    end
  end

  defp avatar_status_label(avatars_by_agent, agent_id) do
    case Map.get(avatars_by_agent, agent_id) do
      nil -> "No avatar yet"
      %{status: :queued} -> "Avatar queued"
      %{status: :running} -> "Avatar generating"
      %{status: :failed} -> "Avatar failed"
      %{status: :ready} -> "Avatar ready"
      _ -> "Avatar pending"
    end
  end
end
