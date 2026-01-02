defmodule SwatiWeb.IntegrationsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Integrations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Integrations</h1>
            <p class="text-sm text-base-content/70">Connect MCP servers and tools.</p>
          </div>
          <.button navigate={~p"/integrations/new"}>New integration</.button>
        </div>

        <.table>
          <.table_head>
            <:col>Name</:col>
            <:col>Type</:col>
            <:col>Status</:col>
            <:col>Last test</:col>
            <:col></:col>
          </.table_head>
          <.table_body>
            <.table_row :for={integration <- @integrations}>
              <:cell class="font-medium">
                <.link
                  id={"integration-#{integration.id}-link"}
                  navigate={~p"/integrations/#{integration.id}"}
                  class="underline"
                >
                  {integration.name}
                </.link>
              </:cell>
              <:cell>{integration.type}</:cell>
              <:cell>
                <.badge color={status_color(integration.status)} variant="soft">
                  {integration.status}
                </.badge>
              </:cell>
              <:cell>{integration.last_test_status || "—"}</:cell>
              <:cell class="text-right">
                <div class="flex items-center justify-end gap-2">
                  <.button size="sm" variant="ghost" phx-click="test" phx-value-id={integration.id}>
                    Test
                  </.button>
                  <.link
                    class="text-sm underline"
                    navigate={~p"/integrations/#{integration.id}/edit"}
                  >
                    Edit
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
    integrations = Integrations.list_integrations(tenant.id)

    {:ok, assign(socket, integrations: integrations)}
  end

  @impl true
  def handle_event("test", %{"id" => id}, socket) do
    integration = Integrations.get_integration!(socket.assigns.current_scope.tenant.id, id)

    case Integrations.test_integration(integration) do
      {:ok, _integration, _tools} ->
        {:noreply,
         socket
         |> put_flash(:info, "Connection succeeded.")
         |> refresh_integrations()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Connection failed.")
         |> refresh_integrations()}
    end
  end

  defp refresh_integrations(socket) do
    tenant = socket.assigns.current_scope.tenant
    assign(socket, integrations: Integrations.list_integrations(tenant.id))
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(_), do: "neutral"
end
