defmodule SwatiWeb.IntegrationsLive.Show do
  use SwatiWeb, :live_view

  alias Swati.Integrations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div class="space-y-2">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="text-2xl font-semibold">{@integration.name}</h1>
              <.badge color="info" variant="soft">{type_label(@integration.type)}</.badge>
              <.badge color={status_color(@integration.status)} variant="soft">
                {status_label(@integration.status)}
              </.badge>
            </div>
            <p class="text-sm text-base-content/70">{@integration.endpoint_url}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.button
              id="integration-test-button"
              variant="soft"
              phx-click="test"
              phx-value-id={@integration.id}
            >
              Test connection
            </.button>
            <.button
              id="integration-edit-button"
              navigate={~p"/integrations/#{@integration.id}/edit"}
            >
              Edit
            </.button>
            <.button
              id="integration-back-button"
              navigate={~p"/agent-data"}
              variant="ghost"
            >
              Back
            </.button>
          </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Status</p>
            <div class="mt-2 flex items-center gap-2">
              <.badge color={status_color(@integration.status)} variant="soft">
                {status_label(@integration.status)}
              </.badge>
              <span class="text-xs text-base-content/60">
                {last_test_label(@integration.last_tested_at)}
              </span>
            </div>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Protocol
            </p>
            <p class="mt-2 text-sm font-medium">{@integration.protocol_version}</p>
            <p class="text-xs text-base-content/60">{@integration.origin}</p>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Timeout</p>
            <p class="mt-2 text-sm font-medium">{@integration.timeout_secs}s</p>
            <p class="text-xs text-base-content/60">Streamable HTTP</p>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Auth
            </p>
            <p class="mt-2 text-sm font-medium">{auth_label(@integration.auth_type)}</p>
            <p class="text-xs text-base-content/60">{auth_hint(@integration.auth_type)}</p>
          </section>
        </div>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <div class="space-y-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold">Connection</h2>
                <.badge color="info" variant="soft">MCP</.badge>
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Server URL
                  </p>
                  <p class="mt-1 text-sm font-medium break-all">{@integration.endpoint_url}</p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Origin
                  </p>
                  <p class="mt-1 text-sm font-medium">{@integration.origin}</p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Protocol version
                  </p>
                  <p class="mt-1 text-sm font-medium">{@integration.protocol_version}</p>
                </div>
                <div>
                  <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                    Request timeout
                  </p>
                  <p class="mt-1 text-sm font-medium">{@integration.timeout_secs}s</p>
                </div>
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Tool access</h2>
              <p class="text-sm text-base-content/70">
                Allowlist and prefix control what the agent can call.
              </p>
              <div class="flex flex-wrap gap-2">
                <%= cond do %>
                  <% @allowed_tools == [] and @allowlist_seeded -> %>
                    <span class="text-sm text-base-content/60">No tools allowed.</span>
                  <% @allowed_tools == [] -> %>
                    <span class="text-sm text-base-content/60">All tools allowed by default.</span>
                  <% true -> %>
                    <.badge :for={tool <- @allowed_tools} color="info" variant="soft">
                      {tool}
                    </.badge>
                <% end %>
              </div>
              <div class="pt-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Tool prefix
                </p>
                <p class="mt-1 text-sm font-medium">{@integration.tool_prefix || "-"}</p>
              </div>
            </section>

            <section
              id="integration-tools"
              class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4"
            >
              <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold">Available tools</h2>
                <span class="text-xs text-base-content/60">
                  {tools_count_label(@available_tools)}
                </span>
              </div>

              <%= cond do %>
                <% @tools_state == :loading -> %>
                  <p class="text-sm text-base-content/60">Loading tools...</p>
                <% @tools_state == :error -> %>
                  <p class="text-sm text-error">
                    {@tools_error || "Unable to load tools."}
                  </p>
                <% @available_tools == [] -> %>
                  <p class="text-sm text-base-content/60">
                    No tools discovered yet. Run Test connection to fetch them.
                  </p>
                <% true -> %>
                  <.form for={@tools_form} id="integration-tools-form" phx-change="toggle_tool">
                    <div class="divide-y divide-base-300">
                      <div
                        :for={tool <- @available_tools}
                        id={"integration-tool-#{tool_key(tool)}"}
                        class="py-3"
                      >
                        <div class="flex items-start justify-between gap-4">
                          <div class="space-y-1">
                            <p class="text-sm font-medium">{tool_name(tool)}</p>
                            <p class="text-xs text-base-content/60">
                              {tool_description(tool)}
                            </p>
                          </div>
                          <div class="flex items-center gap-4">
                            <.badge color="info" variant="soft">
                              {tool_params_label(tool)}
                            </.badge>
                            <div class="flex items-center gap-2">
                              <span class="text-xs text-base-content/60">Allow</span>
                              <.switch
                                name={"tools[#{tool_key(tool)}]"}
                                checked={tool_allowed?(@allowed_tools, @allowlist_seeded, tool)}
                              />
                            </div>
                            <.button
                              type="button"
                              size="sm"
                              variant="ghost"
                              phx-click="toggle_tool_details"
                              phx-value-tool={tool_key(tool)}
                              aria-expanded={tool_expanded?(@expanded_tools, tool)}
                              aria-label="Toggle tool details"
                              title="Toggle tool details"
                            >
                              <.icon
                                name="hero-chevron-right"
                                class={tool_icon_class(@expanded_tools, tool)}
                              />
                            </.button>
                          </div>
                        </div>
                        <%= if tool_expanded?(@expanded_tools, tool) do %>
                          <% properties = tool_properties(tool) %>
                          <% required = tool_required(tool) %>
                          <div class="mt-3 rounded-xl border border-base-300 bg-base-200/40 p-3 space-y-3">
                            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                              Parameters
                            </p>
                            <%= if properties == [] do %>
                              <p class="text-xs text-base-content/60">No parameters.</p>
                            <% else %>
                              <div class="space-y-2">
                                <div
                                  :for={{name, meta} <- properties}
                                  class="rounded-lg border border-base-300 bg-base-100 p-3"
                                >
                                  <div class="flex flex-wrap items-center gap-2">
                                    <span class="text-xs font-semibold">{name}</span>
                                    <.badge
                                      :if={name in required}
                                      color="warning"
                                      variant="soft"
                                    >
                                      Required
                                    </.badge>
                                    <span class="text-xs text-base-content/60">
                                      {tool_prop_type(meta)}
                                    </span>
                                  </div>
                                  <p class="text-xs text-base-content/60">
                                    {tool_prop_description(meta)}
                                  </p>
                                </div>
                              </div>
                            <% end %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </.form>
              <% end %>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Request headers</h2>
              <p class="text-sm text-base-content/70">
                We only store credentials; tokens are never displayed.
              </p>
              <div class="rounded-xl border border-base-300 bg-base-200/40 p-4 text-xs">
                <%= if @integration.auth_type in [:bearer, "bearer"] do %>
                  <pre phx-no-curly-interpolation>Authorization: Bearer ********</pre>
                <% else %>
                  <p class="text-sm text-base-content/60">No custom headers configured.</p>
                <% end %>
              </div>
            </section>
          </div>

          <div class="space-y-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-3">
              <h2 class="text-lg font-semibold">Health</h2>
              <div class="flex items-center gap-2">
                <.badge color={test_status_color(@integration.last_test_status)} variant="soft">
                  {test_status_label(@integration.last_test_status)}
                </.badge>
                <span class="text-xs text-base-content/60">
                  {last_test_label(@integration.last_tested_at)}
                </span>
              </div>
              <p class="text-sm text-base-content/70">
                {health_summary(@integration.last_test_status)}
              </p>
              <%= if present?(@integration.last_test_error) do %>
                <div class="rounded-xl border border-base-300 bg-base-200/40 p-3 text-xs text-base-content/70">
                  {@integration.last_test_error}
                </div>
              <% end %>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-3">
              <h2 class="text-lg font-semibold">Auth</h2>
              <p class="text-sm text-base-content/70">
                {auth_label(@integration.auth_type)}
              </p>
              <p class="text-xs text-base-content/60">
                {auth_hint(@integration.auth_type)}
              </p>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-3">
              <h2 class="text-lg font-semibold">Notes</h2>
              <p class="text-sm text-base-content/70">
                Keep this server fast: aim for tool responses under {@integration.timeout_secs}s.
              </p>
              <p class="text-sm text-base-content/70">
                Use allowlists to prevent accidental tool calls and reduce latency.
              </p>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    integration = Integrations.get_integration!(socket.assigns.current_scope.tenant.id, id)

    socket =
      socket
      |> assign(:integration, integration)
      |> assign(:allowed_tools, integration.allowed_tools || [])
      |> assign(:allowlist_seeded, integration.allowed_tools != [])
      |> assign(:available_tools, [])
      |> assign(:tools_state, :idle)
      |> assign(:tools_error, nil)
      |> assign(:tools_form, to_form(%{}, as: :tools))
      |> assign(:expanded_tools, MapSet.new())

    socket =
      if connected?(socket) do
        send(self(), :load_tools)
        assign(socket, :tools_state, :loading)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("test", %{"id" => id}, socket) do
    integration = Integrations.get_integration!(socket.assigns.current_scope.tenant.id, id)

    case Integrations.test_integration(integration) do
      {:ok, _integration, tools} ->
        {:noreply,
         socket
         |> put_flash(:info, "Connection succeeded.")
         |> assign(:available_tools, tools)
         |> assign(:tools_state, :ready)
         |> assign(:tools_error, nil)
         |> refresh_integration()
         |> maybe_seed_allowlist(tools)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Connection failed.")
         |> assign(:tools_state, :error)
         |> assign(:tools_error, error_message(reason))
         |> refresh_integration()}
    end
  end

  @impl true
  def handle_event("toggle_tool", %{"tools" => params}, socket) do
    allowlist =
      socket.assigns.available_tools
      |> Enum.map(&tool_name/1)
      |> Enum.filter(fn name ->
        Map.get(params, tool_key_from_name(name)) in ["true", "on", true]
      end)

    update_allowlist(socket, allowlist)
  end

  def handle_event("toggle_tool", _params, socket) do
    update_allowlist(socket, [])
  end

  def handle_event("toggle_tool_details", %{"tool" => tool_key}, socket) do
    expanded_tools =
      if MapSet.member?(socket.assigns.expanded_tools, tool_key) do
        MapSet.delete(socket.assigns.expanded_tools, tool_key)
      else
        MapSet.put(socket.assigns.expanded_tools, tool_key)
      end

    {:noreply, assign(socket, :expanded_tools, expanded_tools)}
  end

  @impl true
  def handle_info(:load_tools, socket) do
    case Integrations.fetch_tools(socket.assigns.integration) do
      {:ok, tools} ->
        {:noreply,
         socket
         |> assign(:available_tools, tools)
         |> assign(:tools_state, :ready)
         |> assign(:tools_error, nil)
         |> maybe_seed_allowlist(tools)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:tools_state, :error)
         |> assign(:tools_error, error_message(reason))}
    end
  end

  defp refresh_integration(socket) do
    integration =
      Integrations.get_integration!(
        socket.assigns.current_scope.tenant.id,
        socket.assigns.integration.id
      )

    socket
    |> assign(:integration, integration)
    |> assign(:allowed_tools, integration.allowed_tools || [])
    |> assign(
      :allowlist_seeded,
      socket.assigns.allowlist_seeded || integration.allowed_tools != []
    )
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:disabled), do: "warning"
  defp status_color(_), do: "info"

  defp status_label(:active), do: "Active"
  defp status_label("active"), do: "Active"
  defp status_label(:disabled), do: "Disabled"
  defp status_label("disabled"), do: "Disabled"

  defp status_label(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.capitalize()

  defp status_label(value) when is_binary(value), do: String.capitalize(value)

  defp type_label(:mcp_streamable_http), do: "MCP Streamable HTTP"
  defp type_label("mcp_streamable_http"), do: "MCP Streamable HTTP"
  defp type_label(value) when is_atom(value), do: value |> Atom.to_string() |> type_label()

  defp type_label(value) when is_binary(value) do
    value
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp auth_label(:bearer), do: "Bearer token"
  defp auth_label("bearer"), do: "Bearer token"
  defp auth_label(:none), do: "No auth"
  defp auth_label("none"), do: "No auth"
  defp auth_label(value) when is_atom(value), do: value |> Atom.to_string() |> String.capitalize()
  defp auth_label(value) when is_binary(value), do: String.capitalize(value)

  defp auth_hint(:bearer), do: "Stored securely in secrets."
  defp auth_hint("bearer"), do: "Stored securely in secrets."
  defp auth_hint(:none), do: "Requests sent without auth."
  defp auth_hint("none"), do: "Requests sent without auth."
  defp auth_hint(_), do: "Review auth policy."

  defp test_status_color("success"), do: "success"
  defp test_status_color(:success), do: "success"
  defp test_status_color("error"), do: "danger"
  defp test_status_color(:error), do: "danger"
  defp test_status_color(nil), do: "info"
  defp test_status_color(_), do: "info"

  defp test_status_label("success"), do: "Success"
  defp test_status_label(:success), do: "Success"
  defp test_status_label("error"), do: "Error"
  defp test_status_label(:error), do: "Error"
  defp test_status_label(nil), do: "Not tested"
  defp test_status_label(value) when is_binary(value), do: String.capitalize(value)

  defp test_status_label(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.capitalize()

  defp health_summary("success"), do: "Connection healthy."
  defp health_summary(:success), do: "Connection healthy."
  defp health_summary("error"), do: "Last test failed. Recheck the endpoint and auth."
  defp health_summary(:error), do: "Last test failed. Recheck the endpoint and auth."
  defp health_summary(nil), do: "Run a test to validate the connection."
  defp health_summary(_), do: "Review the latest test result."

  defp last_test_label(nil), do: "Not tested yet"

  defp last_test_label(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M")
  end

  defp last_test_label(_), do: "Not tested yet"

  defp present?(nil), do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: true

  defp tools_count_label(tools) when is_list(tools), do: "#{length(tools)} tools"
  defp tools_count_label(_), do: "0 tools"

  defp tool_name(tool), do: tool_value(tool, "name", :name) || "Unknown tool"

  defp tool_description(tool) do
    description = tool_value(tool, "description", :description)
    if present?(description), do: description, else: "No description provided."
  end

  defp tool_params_label(tool) do
    schema = tool_schema(tool)
    required = tool_value(schema, "required", :required) || []
    properties = tool_value(schema, "properties", :properties) || %{}

    required_count = if is_list(required), do: length(required), else: 0
    params_count = if is_map(properties), do: map_size(properties), else: 0

    cond do
      params_count == 0 -> "No params"
      required_count == 0 -> "#{params_count} params"
      true -> "#{required_count} required"
    end
  end

  defp tool_key(tool) do
    tool
    |> tool_name()
    |> tool_key_from_name()
  end

  defp tool_expanded?(expanded_tools, tool) do
    MapSet.member?(expanded_tools, tool_key(tool))
  end

  defp tool_icon_class(expanded_tools, tool) do
    base = "size-4 transition-transform"
    if tool_expanded?(expanded_tools, tool), do: "#{base} rotate-90", else: base
  end

  defp tool_required(tool) do
    schema = tool_schema(tool)
    required = tool_value(schema, "required", :required) || []
    if is_list(required), do: Enum.map(required, &to_string/1), else: []
  end

  defp tool_properties(tool) do
    schema = tool_schema(tool)
    properties = tool_value(schema, "properties", :properties) || %{}

    properties
    |> Enum.map(fn {name, meta} -> {to_string(name), meta || %{}} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp tool_prop_type(meta) when is_map(meta) do
    case Map.get(meta, "type") || Map.get(meta, :type) do
      nil -> "—"
      list when is_list(list) -> Enum.join(Enum.map(list, &to_string/1), ", ")
      value -> to_string(value)
    end
  end

  defp tool_prop_type(_), do: "—"

  defp tool_prop_description(meta) when is_map(meta) do
    Map.get(meta, "description") || Map.get(meta, :description) || "—"
  end

  defp tool_prop_description(_), do: "—"

  defp tool_key_from_name(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]+/, "-")
    |> String.trim("-")
  end

  defp tool_schema(tool) do
    tool_value(tool, "inputSchema", :inputSchema) || %{}
  end

  defp tool_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp tool_allowed?(allowed_tools, allowlist_seeded, tool) do
    name = tool_name(tool)

    cond do
      allowlist_seeded -> name in allowed_tools
      allowed_tools == [] -> true
      true -> name in allowed_tools
    end
  end

  defp maybe_seed_allowlist(socket, tools) do
    if socket.assigns.allowlist_seeded or tools == [] do
      socket
    else
      allowlist = tools |> Enum.map(&tool_name/1) |> Enum.uniq()

      case Integrations.update_integration(
             socket.assigns.integration,
             %{"allowed_tools" => allowlist},
             socket.assigns.current_scope.user
           ) do
        {:ok, integration} ->
          socket
          |> assign(:integration, integration)
          |> assign(:allowed_tools, integration.allowed_tools || [])
          |> assign(:allowlist_seeded, true)

        {:error, _reason} ->
          socket
      end
    end
  end

  defp update_allowlist(socket, allowlist) do
    case Integrations.update_integration(
           socket.assigns.integration,
           %{"allowed_tools" => allowlist},
           socket.assigns.current_scope.user
         ) do
      {:ok, integration} ->
        {:noreply,
         socket
         |> assign(:integration, integration)
         |> assign(:allowed_tools, integration.allowed_tools || [])
         |> assign(:allowlist_seeded, true)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to update allowlist.")}
    end
  end

  defp error_message(%Ecto.Changeset{}), do: "Unable to update integration test status."
  defp error_message(reason) when is_binary(reason), do: reason
  defp error_message(reason), do: to_string(reason)
end
