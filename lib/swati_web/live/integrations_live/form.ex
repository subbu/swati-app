defmodule SwatiWeb.IntegrationsLive.Form do
  use SwatiWeb, :live_view

  alias Swati.Integrations
  alias Swati.Integrations.Integration

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.live_component
        module={SwatiWeb.IntegrationsLive.FormComponent}
        id="integration-form-component"
        integration={@integration}
        action={@live_action}
        current_scope={@current_scope}
        show_back={true}
        back_to={~p"/agent-data"}
        return_to={~p"/agent-data"}
        return_action={:navigate}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        {:noreply, assign(socket, :integration, %Integration{})}

      :edit ->
        integration =
          Integrations.get_integration!(socket.assigns.current_scope.tenant.id, params["id"])

        {:noreply, assign(socket, :integration, integration)}
    end
  end
end
