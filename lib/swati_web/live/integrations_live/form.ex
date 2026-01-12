defmodule SwatiWeb.IntegrationsLive.Form do
  use SwatiWeb, :live_view

  alias Swati.Integrations
  alias Swati.Integrations.Integration

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">{@page_title}</h1>
            <p class="text-sm text-base-content/70">Store endpoint, auth, and allowlists.</p>
          </div>
          <.button navigate={~p"/agent-data"} variant="ghost">Back</.button>
        </div>

        <.form for={@form} id="integration-form" phx-change="validate" phx-submit="save">
          <div class="grid gap-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Connection</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@form[:name]} label="Name" required />
                <.select field={@form[:type]} label="Type" options={@type_options} />
                <.input field={@form[:endpoint_url]} label="Endpoint URL" required />
                <.input field={@form[:origin]} label="Origin" />
                <.input field={@form[:protocol_version]} label="Protocol version" />
                <.input field={@form[:timeout_secs]} label="Timeout (seconds)" type="number" />
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Tools</h2>
              <.textarea
                name="integration[allowed_tools]"
                label="Allowed tools"
                value={@allowed_tools}
              />
              <.input field={@form[:tool_prefix]} label="Tool prefix" />
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Authentication</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.select field={@form[:auth_type]} label="Auth type" options={@auth_type_options} />
                <.input name="integration[auth_token]" label="Bearer token" value={@auth_token} />
              </div>
            </section>
          </div>

          <div class="flex justify-end">
            <.button type="submit">Save integration</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:type_options, type_options())
     |> assign(:auth_type_options, auth_type_options())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        integration = %Integration{}

        {:noreply,
         socket
         |> assign(:page_title, "New integration")
         |> assign_integration(integration, %{})}

      :edit ->
        integration =
          Integrations.get_integration!(socket.assigns.current_scope.tenant.id, params["id"])

        {:noreply,
         socket
         |> assign(:page_title, "Edit integration")
         |> assign_integration(integration, %{})}
    end
  end

  @impl true
  def handle_event("validate", %{"integration" => params}, socket) do
    changeset =
      socket.assigns.integration
      |> Integration.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_integration(socket, socket.assigns.integration, params, changeset)}
  end

  @impl true
  def handle_event("save", %{"integration" => params}, socket) do
    case socket.assigns.live_action do
      :new ->
        case Integrations.create_integration(
               socket.assigns.current_scope.tenant.id,
               params,
               socket.assigns.current_scope.user
             ) do
          {:ok, _integration} ->
            {:noreply,
             socket
             |> put_flash(:info, "Integration created.")
             |> push_navigate(to: ~p"/agent-data")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_integration(socket, socket.assigns.integration, params, changeset)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, to_string(reason))}
        end

      :edit ->
        case Integrations.update_integration(
               socket.assigns.integration,
               params,
               socket.assigns.current_scope.user
             ) do
          {:ok, integration} ->
            {:noreply,
             socket
             |> put_flash(:info, "Integration updated.")
             |> assign_integration(integration, %{})}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_integration(socket, socket.assigns.integration, params, changeset)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, to_string(reason))}
        end
    end
  end

  defp assign_integration(socket, integration, params, changeset \\ nil) do
    changeset = changeset || Integration.changeset(integration, params)

    socket
    |> assign(:integration, integration)
    |> assign(:form, to_form(changeset, as: :integration))
    |> assign(
      :allowed_tools,
      Map.get(params, "allowed_tools") || Enum.join(integration.allowed_tools || [], "\n")
    )
    |> assign(:auth_token, Map.get(params, "auth_token", ""))
  end

  defp type_options do
    [{"MCP Streamable HTTP", "mcp_streamable_http"}]
  end

  defp auth_type_options do
    [{"None", "none"}, {"Bearer", "bearer"}]
  end
end
