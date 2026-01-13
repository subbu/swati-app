defmodule SwatiWeb.IntegrationsLive.FormComponent do
  use SwatiWeb, :live_component

  alias Swati.Integrations
  alias Swati.Integrations.Integration

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full flex-col">
      <div class="flex-1 overflow-y-auto">
        <div class="mx-auto w-full max-w-4xl space-y-8">
          <div class="flex items-center justify-between gap-4 border-b border-base pb-6">
            <div>
              <h2 class="text-2xl font-semibold text-foreground">{@page_title}</h2>
              <p class="text-sm text-foreground-softer">
                Store endpoint, auth, and allowlists.
              </p>
            </div>
            <.button :if={@show_back} navigate={@back_to} variant="ghost">
              Back
            </.button>
          </div>

          <.form
            for={@form}
            id="integration-form"
            phx-change="validate"
            phx-submit="save"
            phx-target={@myself}
            class="space-y-8"
          >
            <div>
              <h2 class="font-semibold text-foreground">Connection</h2>
              <p class="text-sm text-foreground-softer">
                Store endpoint, protocol, and timeout settings.
              </p>
              <div class="mt-6 w-full max-w-3xl space-y-6">
                <div class="grid gap-4 md:grid-cols-2">
                  <.input field={@form[:name]} label="Name" required />
                  <.select field={@form[:type]} label="Type" options={@type_options} />
                  <.input field={@form[:endpoint_url]} label="Endpoint URL" required />
                  <.input field={@form[:origin]} label="Origin" />
                  <.input field={@form[:protocol_version]} label="Protocol version" />
                  <.input field={@form[:timeout_secs]} label="Timeout (seconds)" type="number" />
                </div>
              </div>
            </div>

            <div>
              <h2 class="font-semibold text-foreground">Tools</h2>
              <p class="text-sm text-foreground-softer">
                Control the tool allowlist and prefix.
              </p>
              <div class="mt-6 w-full max-w-3xl space-y-6">
                <.textarea
                  name="integration[allowed_tools]"
                  label="Allowed tools"
                  value={@allowed_tools}
                />
                <.input field={@form[:tool_prefix]} label="Tool prefix" />
              </div>
            </div>

            <div>
              <h2 class="font-semibold text-foreground">Authentication</h2>
              <p class="text-sm text-foreground-softer">
                Provide the credentials for the integration.
              </p>
              <div class="mt-6 w-full max-w-3xl space-y-6">
                <div class="grid gap-4 md:grid-cols-2">
                  <.select field={@form[:auth_type]} label="Auth type" options={@auth_type_options} />
                  <.input name="integration[auth_token]" label="Bearer token" value={@auth_token} />
                </div>
              </div>
            </div>

            <div class="flex justify-end">
              <.button type="submit">{@save_label}</.button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    action = Map.get(assigns, :action, :new)
    page_title = if action == :edit, do: "Edit integration", else: "New integration"
    save_label = if action == :edit, do: "Save changes", else: "Save integration"
    previous_integration = socket.assigns[:integration]

    socket =
      socket
      |> assign(assigns)
      |> assign(:type_options, type_options())
      |> assign(:auth_type_options, auth_type_options())
      |> assign(:page_title, page_title)
      |> assign(:save_label, save_label)
      |> assign_new(:show_back, fn -> false end)
      |> assign_new(:back_to, fn -> nil end)
      |> assign_new(:return_to, fn -> nil end)
      |> assign_new(:return_action, fn -> :navigate end)

    socket =
      if previous_integration != assigns.integration or is_nil(socket.assigns[:form]) do
        assign_integration(socket, assigns.integration, %{})
      else
        socket
      end

    {:ok, socket}
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
    case socket.assigns.action do
      :new ->
        case Integrations.create_integration(
               socket.assigns.current_scope.tenant.id,
               params,
               socket.assigns.current_scope.user
             ) do
          {:ok, _integration} ->
            socket =
              socket
              |> put_flash(:info, "Integration created.")
              |> maybe_refresh_integrations()
              |> return_after_save()

            {:noreply, socket}

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

  defp maybe_refresh_integrations(socket) do
    case socket.assigns.return_action do
      :patch ->
        send(self(), :refresh_integrations)
        socket

      _ ->
        socket
    end
  end

  defp return_after_save(socket) do
    case {socket.assigns.return_action, socket.assigns.return_to} do
      {:patch, return_to} when is_binary(return_to) ->
        push_patch(socket, to: return_to)

      {:navigate, return_to} when is_binary(return_to) ->
        push_navigate(socket, to: return_to)

      _ ->
        socket
    end
  end

  defp type_options do
    [{"MCP Streamable HTTP", "mcp_streamable_http"}]
  end

  defp auth_type_options do
    [{"None", "none"}, {"Bearer", "bearer"}]
  end
end
