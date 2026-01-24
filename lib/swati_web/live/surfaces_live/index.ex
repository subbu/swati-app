defmodule SwatiWeb.SurfacesLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Channels.Imap
  alias Swati.Repo

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    surfaces = Channels.unified_surfaces_view(tenant.id)
    connections = Channels.list_connections(tenant.id) |> Repo.preload([:channel, :endpoint])
    connections_by_provider = Enum.group_by(connections, & &1.provider)
    imap_defaults = Imap.default_params()

    # Compute aggregate stats
    stats = compute_aggregate_stats(surfaces)

    providers = [
      %{
        id: :gmail,
        name: "Gmail",
        description: "Google Workspace and Gmail inboxes.",
        icon: "hero-envelope",
        status: :available
      },
      %{
        id: :outlook,
        name: "Outlook",
        description: "Microsoft 365 and Outlook inboxes.",
        icon: "hero-inbox",
        status: :available
      },
      %{
        id: :imap,
        name: "IMAP/SMTP",
        description: "Custom IMAP/SMTP credentials.",
        icon: "hero-server-stack",
        status: :available
      }
    ]

    # Load all agents for assignment modal
    all_agents = Agents.list_agents(tenant.id)

    {:ok,
     socket
     |> assign(:surfaces, surfaces)
     |> assign(:stats, stats)
     |> assign(:connections, connections)
     |> assign(:connections_by_provider, connections_by_provider)
     |> assign(:providers, providers)
     |> assign(:sync_providers, Channels.sync_providers())
     |> assign(:expanded_surface, nil)
     |> assign(:selected_endpoint, nil)
     |> assign(:endpoint_sheet_open, false)
     |> assign(:agent_modal_open, false)
     |> assign(:agent_modal_surface, nil)
     |> assign(:all_agents, all_agents)
     |> assign(:imap_sheet_open, false)
     |> assign(:imap_preset, :custom)
     |> assign(:imap_provider_label, Map.get(imap_defaults, "provider_label"))
     |> assign(:imap_form, to_form(Imap.changeset(imap_defaults), as: :imap))}
  end

  @impl true
  def handle_event("toggle_surface", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)

    expanded =
      if socket.assigns.expanded_surface == type_atom do
        nil
      else
        type_atom
      end

    {:noreply, assign(socket, :expanded_surface, expanded)}
  end

  def handle_event("sync_connection", %{"id" => connection_id}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id

    case Channels.enqueue_sync_connection(tenant_id, connection_id) do
      {:ok, _job} ->
        {:noreply, put_flash(socket, :info, "Sync queued.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to queue sync.")}
    end
  end

  def handle_event("open-imap-sheet", params, socket) do
    preset = imap_preset_from_params(params)
    defaults = Imap.default_params(preset)

    {:noreply,
     socket
     |> assign(:imap_sheet_open, true)
     |> assign(:imap_preset, preset)
     |> assign(:imap_provider_label, Map.get(defaults, "provider_label"))
     |> assign(:imap_form, to_form(Imap.changeset(defaults), as: :imap))}
  end

  def handle_event("close-imap-sheet", _params, socket) do
    {:noreply, assign(socket, :imap_sheet_open, false)}
  end

  def handle_event("save-imap-connection", %{"imap" => params}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    params = maybe_put_provider_label(params, socket.assigns.imap_provider_label)

    case Channels.connect_imap(tenant_id, params) do
      {:ok, _connection} ->
        defaults = Imap.default_params()

        {:noreply,
         socket
         |> clear_flash(:error)
         |> put_flash(:info, "IMAP connection saved.")
         |> assign(:imap_sheet_open, false)
         |> assign(:imap_preset, :custom)
         |> assign(:imap_provider_label, Map.get(defaults, "provider_label"))
         |> assign(:imap_form, to_form(Imap.changeset(defaults), as: :imap))
         |> reload_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :imap_form, to_form(changeset, as: :imap))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to connect IMAP: #{inspect(reason)}")
         |> assign(:imap_sheet_open, true)}
    end
  end

  def handle_event("select_endpoint", %{"id" => endpoint_id}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    endpoint = Channels.get_endpoint!(tenant_id, endpoint_id) |> Repo.preload(:channel)
    connection = Channels.get_connection_by_endpoint(tenant_id, endpoint_id)

    # Get agent assignments for this endpoint's channel
    agent_assignments =
      if endpoint.channel do
        get_agent_assignments_for_channel(tenant_id, endpoint.channel.id)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:selected_endpoint, endpoint)
     |> assign(:endpoint_connection, connection)
     |> assign(:endpoint_agent_assignments, agent_assignments)
     |> assign(:endpoint_sheet_open, true)}
  end

  def handle_event("close-endpoint-sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:endpoint_sheet_open, false)
     |> assign(:selected_endpoint, nil)}
  end

  def handle_event("open_agent_modal", %{"surface-type" => surface_type}, socket) do
    {:noreply,
     socket
     |> assign(:agent_modal_open, true)
     |> assign(:agent_modal_surface, String.to_existing_atom(surface_type))}
  end

  def handle_event("close-agent-modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:agent_modal_open, false)
     |> assign(:agent_modal_surface, nil)}
  end

  def handle_event("assign_agent", %{"agent_id" => agent_id, "autonomy_level" => autonomy_level}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    surface_type = socket.assigns.agent_modal_surface

    # Find the channel for this surface type
    surface = Enum.find(socket.assigns.surfaces, fn s -> s.type == surface_type end)

    case surface do
      nil ->
        {:noreply, put_flash(socket, :error, "Surface not found.")}

      %{channels: []} ->
        {:noreply, put_flash(socket, :error, "No channels available for this surface.")}

      %{channels: [channel | _]} ->
        case Agents.assign_agent_to_channel(tenant_id, agent_id, channel.id, %{
               autonomy_level: autonomy_level
             }) do
          {:ok, _agent_channel} ->
            {:noreply,
             socket
             |> put_flash(:info, "Agent assigned successfully.")
             |> assign(:agent_modal_open, false)
             |> assign(:agent_modal_surface, nil)
             |> reload_data()}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to assign agent.")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <%!-- Page Header --%>
        <header class="relative">
          <div class="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-2">
              <div class="flex items-center gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-primary/20 to-secondary/20 ring-1 ring-primary/10">
                  <.icon name="hero-globe-alt" class="h-5 w-5 text-primary" />
                </div>
                <div>
                  <h1 class="text-2xl font-semibold tracking-tight">Surfaces</h1>
                  <p class="text-sm text-base-content/60">Where Swati meets your customers</p>
                </div>
              </div>
            </div>
            <div class="flex items-center gap-3">
              <.dropdown placement="bottom-end">
                <:toggle>
                  <.button variant="solid">
                    <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add Surface
                  </.button>
                </:toggle>
                <.dropdown_link navigate={~p"/numbers"}>
                  <.icon name="hero-phone" class="icon" /> Phone Number
                </.dropdown_link>
                <.dropdown_link navigate={~p"/channels/gmail/connect"}>
                  <.icon name="hero-envelope" class="icon" /> Gmail
                </.dropdown_link>
                <.dropdown_link navigate={~p"/channels/outlook/connect"}>
                  <.icon name="hero-inbox" class="icon" /> Outlook
                </.dropdown_link>
                <.dropdown_button id="connect-zoho" phx-click="open-imap-sheet" phx-value-preset="zoho">
                  <.icon name="hero-envelope" class="icon" /> Zoho Mail
                </.dropdown_button>
                <.dropdown_button
                  id="connect-imap"
                  phx-click="open-imap-sheet"
                  phx-value-preset="custom"
                >
                  <.icon name="hero-server-stack" class="icon" /> IMAP/SMTP
                </.dropdown_button>
              </.dropdown>
            </div>
          </div>
        </header>

        <%!-- KPI Ribbon --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <div class="flex flex-col items-center p-4 bg-base-100 border border-base-300 rounded-lg">
            <span class="text-2xl font-bold text-base-content">{@stats.surface_count}</span>
            <span class="text-xs text-base-content/50 mt-1">Surfaces</span>
          </div>
          <div class="flex flex-col items-center p-4 bg-base-100 border border-base-300 rounded-lg">
            <span class="text-2xl font-bold text-base-content">{@stats.endpoint_count}</span>
            <span class="text-xs text-base-content/50 mt-1">Endpoints</span>
          </div>
          <div class="flex flex-col items-center p-4 bg-base-100 border border-base-300 rounded-lg">
            <span class="text-2xl font-bold text-base-content">{format_health_percent(@stats.health_percent)}</span>
            <span class="text-xs text-base-content/50 mt-1">Health</span>
          </div>
          <div class="flex flex-col items-center p-4 bg-base-100 border border-base-300 rounded-lg">
            <span class="text-2xl font-bold text-base-content">{@stats.agent_count}</span>
            <span class="text-xs text-base-content/50 mt-1">Agents</span>
          </div>
        </div>

        <%!-- Surface Cards Grid --%>
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <%= for surface <- @surfaces do %>
            <.surface_card
              surface={surface}
              expanded={@expanded_surface == surface.type}
              connections_by_provider={@connections_by_provider}
              sync_providers={@sync_providers}
            />
          <% end %>
        </div>
      </div>

      <%!-- IMAP Connection Sheet --%>
      <.sheet
        id="imap-connection-sheet"
        placement="right"
        class="w-full max-w-2xl"
        open={@imap_sheet_open}
        on_close={JS.push("close-imap-sheet")}
      >
        <div class="space-y-6">
          <header class="space-y-1">
            <%= if @imap_provider_label do %>
              <h3 class="text-lg font-semibold text-foreground">Connect {@imap_provider_label}</h3>
              <p class="text-sm text-foreground-soft">
                Use an app-specific password and verify IMAP/SMTP access is enabled.
              </p>
            <% else %>
              <h3 class="text-lg font-semibold text-foreground">Connect IMAP/SMTP</h3>
              <p class="text-sm text-foreground-soft">
                Add custom inbox credentials (Zoho, Fastmail, on-premise, etc).
              </p>
            <% end %>
          </header>

          <.form for={@imap_form} id="imap-connection-form" phx-submit="save-imap-connection">
            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@imap_form[:email_address]} label="Inbox email" type="email" />
              <.input field={@imap_form[:display_name]} label="Display name" type="text" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@imap_form[:imap_host]} label="IMAP host" type="text" />
              <.input field={@imap_form[:imap_port]} label="IMAP port" type="number" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@imap_form[:imap_username]} label="IMAP username" type="text" />
              <.input field={@imap_form[:imap_password]} label="IMAP password" type="password" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@imap_form[:smtp_host]} label="SMTP host" type="text" />
              <.input field={@imap_form[:smtp_port]} label="SMTP port" type="number" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.input field={@imap_form[:smtp_username]} label="SMTP username" type="text" />
              <.input field={@imap_form[:smtp_password]} label="SMTP password" type="password" />
            </div>

            <div class="grid gap-4 md:grid-cols-2">
              <.checkbox field={@imap_form[:imap_ssl]} label="IMAP SSL (993)" />
              <.checkbox field={@imap_form[:smtp_ssl]} label="SMTP SSL (465)" />
            </div>

            <div class="flex items-center justify-end pt-2">
              <.button type="submit" variant="solid">Save connection</.button>
            </div>
          </.form>
        </div>
      </.sheet>

      <%!-- Endpoint Detail Sheet --%>
      <.sheet
        id="endpoint-detail-sheet"
        placement="right"
        class="w-full max-w-2xl"
        open={@endpoint_sheet_open}
        on_close={JS.push("close-endpoint-sheet")}
      >
        <%= if @selected_endpoint do %>
          <div class="space-y-6">
            <header class="space-y-1">
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="close-endpoint-sheet"
                  class="text-base-content/60 hover:text-base-content transition-colors"
                >
                  <.icon name="hero-arrow-left" class="h-4 w-4" />
                </button>
                <span class="text-sm text-base-content/60">
                  Back to {if @selected_endpoint.channel, do: surface_label(@selected_endpoint.channel.type), else: "Surface"}
                </span>
              </div>
              <h3 class="text-lg font-semibold text-foreground font-mono">{@selected_endpoint.address}</h3>
              <p class="text-sm text-foreground-soft">
                {endpoint_type_label(@selected_endpoint)} · {if @selected_endpoint.channel, do: @selected_endpoint.channel.name, else: "Unknown channel"}
              </p>
            </header>

            <%!-- Connection Info --%>
            <section class="space-y-3">
              <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">Connection</h4>
              <%= if @endpoint_connection do %>
                <div class="rounded-lg border border-base-300 bg-base-200/30 p-4 space-y-3">
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-base-content/70">Provider</span>
                    <span class="text-sm font-medium text-base-content">{provider_label(@endpoint_connection)}</span>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-base-content/70">Status</span>
                    <.badge size="xs" variant="soft" color={connection_status_color(@endpoint_connection.status)}>
                      {@endpoint_connection.status}
                    </.badge>
                  </div>
                  <div class="flex items-center justify-between">
                    <span class="text-sm text-base-content/70">Last Activity</span>
                    <span class="text-sm text-base-content">
                      {if @endpoint_connection.last_synced_at, do: format_datetime(@endpoint_connection.last_synced_at), else: "Never"}
                    </span>
                  </div>
                </div>
              <% else %>
                <div class="rounded-lg border border-dashed border-base-300 bg-base-200/30 p-4 text-center">
                  <p class="text-sm text-base-content/50">No connection configured</p>
                </div>
              <% end %>
            </section>

            <%!-- Assigned Agents --%>
            <section class="space-y-3">
              <div class="flex items-center justify-between">
                <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">Assigned Agents</h4>
                <.button
                  size="xs"
                  variant="ghost"
                  phx-click="open_agent_modal"
                  phx-value-surface-type={if @selected_endpoint.channel, do: @selected_endpoint.channel.type, else: "custom"}
                >
                  <.icon name="hero-plus" class="h-3 w-3 mr-1" /> Assign
                </.button>
              </div>
              <%= if @endpoint_agent_assignments == [] do %>
                <div class="rounded-lg border border-dashed border-base-300 bg-base-200/30 p-4 text-center">
                  <p class="text-sm text-base-content/50">No agents assigned to this channel</p>
                </div>
              <% else %>
                <div class="space-y-2">
                  <%= for assignment <- @endpoint_agent_assignments do %>
                    <div class="rounded-lg border border-base-300 bg-base-100 p-3 flex items-center justify-between">
                      <div class="flex items-center gap-3">
                        <div class={"flex h-8 w-8 items-center justify-center rounded-full text-xs font-semibold " <> agent_avatar_class(assignment.agent.name)}>
                          {agent_initial(assignment.agent.name)}
                        </div>
                        <div>
                          <div class="font-medium text-sm text-base-content">{assignment.agent.name}</div>
                          <div class="text-xs text-base-content/50">{scope_label(assignment.scope)}</div>
                        </div>
                      </div>
                      <.autonomy_indicator level={assignment.autonomy_level} />
                    </div>
                  <% end %>
                </div>
              <% end %>
            </section>
          </div>
        <% end %>
      </.sheet>

      <%!-- Agent Assignment Modal --%>
      <.modal
        id="agent-assignment-modal"
        open={@agent_modal_open}
        on_close={JS.push("close-agent-modal")}
      >
        <div class="space-y-6">
          <header>
            <h3 class="text-lg font-semibold text-foreground">
              Assign Agent to {if @agent_modal_surface, do: surface_label(@agent_modal_surface), else: "Surface"}
            </h3>
          </header>

          <.form
            for={%{}}
            as={:assignment}
            phx-submit="assign_agent"
            class="space-y-6"
          >
            <section class="space-y-3">
              <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">Select Agent</h4>
              <div class="space-y-2 max-h-48 overflow-y-auto">
                <%= for agent <- @all_agents do %>
                  <label class="flex items-center gap-3 rounded-lg border border-base-300 bg-base-100 p-3 cursor-pointer hover:bg-base-200/50 transition-colors">
                    <input type="radio" name="assignment[agent_id]" value={agent.id} class="radio radio-sm" />
                    <div class={"flex h-8 w-8 items-center justify-center rounded-full text-xs font-semibold " <> agent_avatar_class(agent.name)}>
                      {agent_initial(agent.name)}
                    </div>
                    <div class="flex-1">
                      <div class="font-medium text-sm text-base-content">{agent.name}</div>
                      <div class="text-xs text-base-content/50">{agent.status} · {agent.language}</div>
                    </div>
                  </label>
                <% end %>
              </div>
            </section>

            <section class="space-y-3">
              <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">Autonomy Level</h4>
              <div class="grid grid-cols-4 gap-2">
                <label class="flex flex-col items-center gap-1.5 py-3 px-2 border border-base-300 rounded-lg cursor-pointer transition-all bg-base-100 hover:border-base-content/30 hover:bg-base-200/50 has-[:checked]:border-base-content/50 has-[:checked]:bg-base-200">
                  <input type="radio" name="assignment[autonomy_level]" value="shadow" class="hidden" />
                  <span class="text-xl">👁️</span>
                  <span class="text-xs font-medium text-base-content">Shadow</span>
                </label>
                <label class="flex flex-col items-center gap-1.5 py-3 px-2 border border-base-300 rounded-lg cursor-pointer transition-all bg-base-100 hover:border-amber-400 hover:bg-amber-50 dark:hover:bg-amber-900/20 has-[:checked]:border-amber-500 has-[:checked]:bg-amber-50 dark:has-[:checked]:bg-amber-900/20">
                  <input type="radio" name="assignment[autonomy_level]" value="draft" class="hidden" checked />
                  <span class="text-xl">📝</span>
                  <span class="text-xs font-medium text-base-content">Draft</span>
                </label>
                <label class="flex flex-col items-center gap-1.5 py-3 px-2 border border-base-300 rounded-lg cursor-pointer transition-all bg-base-100 hover:border-emerald-400 hover:bg-emerald-50 dark:hover:bg-emerald-900/20 has-[:checked]:border-emerald-500 has-[:checked]:bg-emerald-50 dark:has-[:checked]:bg-emerald-900/20">
                  <input type="radio" name="assignment[autonomy_level]" value="execute" class="hidden" />
                  <span class="text-xl">▶️</span>
                  <span class="text-xs font-medium text-base-content">Execute</span>
                </label>
                <label class="flex flex-col items-center gap-1.5 py-3 px-2 border border-base-300 rounded-lg cursor-pointer transition-all bg-base-100 hover:border-violet-400 hover:bg-violet-50 dark:hover:bg-violet-900/20 has-[:checked]:border-violet-500 has-[:checked]:bg-violet-50 dark:has-[:checked]:bg-violet-900/20">
                  <input type="radio" name="assignment[autonomy_level]" value="autopilot" class="hidden" />
                  <span class="text-xl">🚀</span>
                  <span class="text-xs font-medium text-base-content">Autopilot</span>
                </label>
              </div>
              <p class="text-xs text-base-content/50">
                Draft: Agent prepares actions and waits for human approval
              </p>
            </section>

            <div class="flex items-center justify-end gap-3 pt-2">
              <.button type="button" variant="ghost" phx-click="close-agent-modal">Cancel</.button>
              <.button type="submit" variant="solid">Assign Agent</.button>
            </div>
          </.form>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  # Surface Card Component
  defp surface_card(assigns) do
    is_coming_soon = assigns.surface.type in [:chat, :whatsapp]
    has_data = length(assigns.surface.channels) > 0

    assigns =
      assigns
      |> assign(:is_coming_soon, is_coming_soon)
      |> assign(:has_data, has_data)

    ~H"""
    <div class={[
      "relative bg-base-100 border border-base-300 rounded-xl p-5 transition-all overflow-hidden",
      "before:absolute before:top-0 before:left-0 before:right-0 before:h-[3px] before:transition-transform before:scale-x-0",
      surface_accent_class(@surface.type),
      !@is_coming_soon && "hover:-translate-y-0.5 hover:shadow-md hover:before:scale-x-100",
      @is_coming_soon && "opacity-60 pointer-events-none"
    ]}>
      <%!-- Card Header --%>
      <div class="flex items-start justify-between gap-3">
        <div class="flex items-center gap-3">
          <div class="flex h-10 w-10 items-center justify-center rounded-lg bg-base-200 text-base-content/70">
            <.icon name={surface_icon(@surface.type)} class="h-5 w-5" />
          </div>
          <div>
            <h3 class="font-semibold text-base-content">{surface_label(@surface.type)}</h3>
            <p class="text-xs text-base-content/50">{surface_description(@surface.type)}</p>
          </div>
        </div>
        <%= if @is_coming_soon do %>
          <.badge size="xs" variant="soft" color="warning">Coming Soon</.badge>
        <% else %>
          <.autonomy_indicator level={highest_autonomy_level(@surface.agents)} />
        <% end %>
      </div>

      <%!-- Stats Grid --%>
      <%= if not @is_coming_soon do %>
        <div class="grid grid-cols-4 gap-2 mt-4 pt-4 border-t border-base-300">
          <div class="text-center">
            <div class="text-lg font-semibold text-base-content leading-tight">{@surface.stats.endpoint_count}</div>
            <div class="text-[11px] text-base-content/50 uppercase tracking-wide mt-0.5">Endpoints</div>
          </div>
          <div class="text-center">
            <div class="text-lg font-semibold text-base-content leading-tight">{@surface.stats.connection_count}</div>
            <div class="text-[11px] text-base-content/50 uppercase tracking-wide mt-0.5">Connections</div>
          </div>
          <div class="text-center">
            <div class="text-lg font-semibold text-base-content leading-tight">{format_last_sync(@surface.stats.last_synced_at)}</div>
            <div class="text-[11px] text-base-content/50 uppercase tracking-wide mt-0.5">Last Sync</div>
          </div>
          <div class="text-center">
            <div class="text-lg font-semibold text-base-content leading-tight">{@surface.stats.agent_count}</div>
            <div class="text-[11px] text-base-content/50 uppercase tracking-wide mt-0.5">Agents</div>
          </div>
        </div>

        <%!-- Endpoint Preview --%>
        <%= if @has_data do %>
          <div class="flex flex-wrap gap-1.5 mt-3">
            <% {shown_endpoints, extra_count} = endpoints_preview(@surface.endpoints) %>
            <span :for={endpoint <- shown_endpoints} class="inline-flex items-center px-2 py-1 text-[11px] font-mono bg-base-200 border border-base-300 rounded-full text-base-content/70">
              {endpoint.address}
            </span>
            <span :if={extra_count > 0} class="inline-flex items-center px-2 py-1 text-[11px] font-mono bg-transparent border border-dashed border-base-300 rounded-full text-base-content/70">
              +{extra_count} more
            </span>
          </div>
        <% end %>

        <%!-- Health & Actions --%>
        <div class="mt-4 flex items-center justify-between">
          <.health_indicator health={@surface.health} />
          <div class="flex items-center gap-2">
            <%= if @has_data do %>
              <.button
                size="xs"
                variant="ghost"
                phx-click="toggle_surface"
                phx-value-type={@surface.type}
              >
                {if @expanded, do: "Collapse", else: "Details"}
              </.button>
            <% end %>
          </div>
        </div>

        <%!-- Expanded Endpoints --%>
        <%= if @expanded and @has_data do %>
          <div class="mt-4 border-t border-base-300 pt-4">
            <h4 class="text-xs font-semibold uppercase tracking-wide text-base-content/50 mb-3">
              Endpoints & Connections
            </h4>
            <div class="space-y-2">
              <%= for endpoint <- @surface.endpoints do %>
                <.endpoint_row
                  endpoint={endpoint}
                  connections={endpoint_connections(@surface.connections, endpoint.id)}
                  sync_providers={@sync_providers}
                />
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="mt-6 flex flex-col items-center justify-center py-4 text-center">
          <div class="flex h-12 w-12 items-center justify-center rounded-full bg-base-200/60">
            <.icon name={surface_icon(@surface.type)} class="h-5 w-5 text-base-content/40" />
          </div>
          <p class="mt-3 text-sm text-base-content/50">
            {surface_label(@surface.type)} support is coming soon.
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Endpoint Row Component
  defp endpoint_row(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-300 bg-base-200/30 p-3">
      <div class="flex items-center justify-between gap-3">
        <div class="min-w-0 flex-1">
          <span class="font-mono text-sm text-base-content">{@endpoint.address}</span>
          <span class="ml-2 text-xs text-base-content/50">{@endpoint.display_name}</span>
        </div>
        <.badge size="xs" variant="soft" color={endpoint_status_color(@endpoint.status)}>
          {@endpoint.status}
        </.badge>
      </div>
      <%= if @connections != [] do %>
        <div class="mt-2 flex flex-wrap items-center gap-2">
          <%= for connection <- @connections do %>
            <div class="flex items-center gap-2 rounded-full bg-base-100 px-2 py-1 text-xs">
              <span class="text-base-content/70">{provider_label(connection)}</span>
              <.badge size="xs" variant="soft" color={connection_status_color(connection.status)}>
                {connection.status}
              </.badge>
              <%= if connection.provider in @sync_providers do %>
                <button
                  type="button"
                  phx-click="sync_connection"
                  phx-value-id={connection.id}
                  class="text-primary hover:text-primary/80 transition-colors"
                >
                  <.icon name="hero-arrow-path" class="h-3 w-3" />
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Autonomy Indicator Component
  defp autonomy_indicator(assigns) do
    level = assigns.level || :draft
    level_index = autonomy_level_index(level)

    assigns =
      assigns
      |> assign(:level, level)
      |> assign(:level_index, level_index)

    ~H"""
    <.tooltip placement="bottom" class="w-[220px]">
      <span class={[
        "inline-flex items-center gap-1.5 px-2 py-1 rounded-md text-xs font-medium cursor-help transition-colors",
        autonomy_badge_class(@level)
      ]}>
        <span>{autonomy_label(@level)}</span>
        <span class="text-[10px] opacity-60">{@level_index + 1}/4</span>
      </span>
      <:content>
        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <span class="text-xs font-medium">Autonomy Level</span>
          </div>
          <%!-- Progress bar --%>
          <div class="flex gap-1">
            <%= for {_lvl, idx} <- Enum.with_index([:shadow, :draft, :execute, :autopilot]) do %>
              <div class={[
                "h-1.5 flex-1 rounded-full transition-colors",
                idx <= @level_index && autonomy_bar_color(@level),
                idx > @level_index && "bg-white/20"
              ]} />
            <% end %>
          </div>
          <%!-- Level descriptions --%>
          <div class="pt-2 space-y-1">
            <%= for {lvl, idx} <- Enum.with_index([:shadow, :draft, :execute, :autopilot]) do %>
              <div class={[
                "flex items-center gap-2 text-xs",
                idx == @level_index && "font-medium",
                idx != @level_index && "opacity-50"
              ]}>
                <span class="w-4 text-center">{idx + 1}.</span>
                <span>{autonomy_label(lvl)}</span>
                <%= if idx == @level_index do %>
                  <span class="ml-auto text-[10px] px-1.5 py-0.5 rounded bg-white/20">Current</span>
                <% end %>
              </div>
            <% end %>
          </div>
          <p class="pt-2 text-[10px] opacity-70 border-t border-white/20">
            {autonomy_description(@level)}
          </p>
        </div>
      </:content>
    </.tooltip>
    """
  end

  defp autonomy_badge_class(:shadow), do: "bg-base-200 text-base-content/70"
  defp autonomy_badge_class(:draft), do: "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400"
  defp autonomy_badge_class(:execute), do: "bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400"
  defp autonomy_badge_class(:autopilot), do: "bg-violet-100 text-violet-700 dark:bg-violet-900/30 dark:text-violet-400"
  defp autonomy_badge_class(_), do: "bg-base-200 text-base-content/70"

  defp autonomy_bar_color(:shadow), do: "bg-base-content/30"
  defp autonomy_bar_color(:draft), do: "bg-amber-500"
  defp autonomy_bar_color(:execute), do: "bg-emerald-500"
  defp autonomy_bar_color(:autopilot), do: "bg-violet-500"
  defp autonomy_bar_color(_), do: "bg-base-content/30"

  # Health Indicator Component
  defp health_indicator(assigns) do
    ~H"""
    <div class="inline-flex items-center gap-1.5">
      <div class={[
        "w-2 h-2 rounded-full shrink-0",
        health_dot_class(@health)
      ]} />
      <span class={["text-xs", health_label_class(@health)]}>{health_label(@health)}</span>
    </div>
    """
  end

  defp health_dot_class(:healthy), do: "bg-emerald-500 animate-pulse"
  defp health_dot_class(:warning), do: "bg-amber-500 animate-pulse"
  defp health_dot_class(:error), do: "bg-red-500 animate-ping"
  defp health_dot_class(:no_data), do: "bg-base-300"
  defp health_dot_class(_), do: "bg-base-300"

  defp health_label_class(:healthy), do: "text-emerald-600 dark:text-emerald-400"
  defp health_label_class(:warning), do: "text-amber-600 dark:text-amber-400"
  defp health_label_class(:error), do: "text-red-600 dark:text-red-400"
  defp health_label_class(_), do: "text-base-content/50"

  # Helper Functions

  defp compute_aggregate_stats(surfaces) do
    active_surfaces = Enum.filter(surfaces, fn s -> length(s.channels) > 0 end)

    endpoint_count = Enum.sum(Enum.map(surfaces, & &1.stats.endpoint_count))
    connection_count = Enum.sum(Enum.map(surfaces, & &1.stats.connection_count))

    agent_ids =
      surfaces
      |> Enum.flat_map(& &1.agents)
      |> Enum.map(& &1.agent.id)
      |> Enum.uniq()

    healthy_count =
      Enum.count(active_surfaces, fn s -> s.health in [:healthy, :no_data] end)

    health_percent =
      if length(active_surfaces) > 0 do
        healthy_count / length(active_surfaces) * 100
      else
        100.0
      end

    %{
      surface_count: length(active_surfaces),
      endpoint_count: endpoint_count,
      connection_count: connection_count,
      agent_count: length(agent_ids),
      health_percent: health_percent
    }
  end

  defp format_health_percent(percent) when is_float(percent) do
    "#{Float.round(percent, 1)}%"
  end

  defp format_health_percent(_), do: "—"

  defp format_last_sync(nil), do: "—"

  defp format_last_sync(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m"
      diff < 1440 -> "#{div(diff, 60)}h"
      true -> "#{div(diff, 1440)}d"
    end
  end

  defp surface_icon(:voice), do: "hero-phone"
  defp surface_icon(:email), do: "hero-envelope"
  defp surface_icon(:chat), do: "hero-chat-bubble-left-right"
  defp surface_icon(:whatsapp), do: "hero-chat-bubble-oval-left"
  defp surface_icon(:custom), do: "hero-puzzle-piece"

  defp surface_accent_class(:voice), do: "before:bg-blue-500"
  defp surface_accent_class(:email), do: "before:bg-orange-500"
  defp surface_accent_class(:chat), do: "before:bg-teal-500"
  defp surface_accent_class(:whatsapp), do: "before:bg-green-500"
  defp surface_accent_class(:custom), do: "before:bg-violet-500"
  defp surface_accent_class(_), do: "before:bg-base-300"

  defp surface_label(:voice), do: "Voice"
  defp surface_label(:email), do: "Email"
  defp surface_label(:chat), do: "Chat"
  defp surface_label(:whatsapp), do: "WhatsApp"
  defp surface_label(:custom), do: "Custom"

  defp surface_description(:voice), do: "Phone calls and voice interactions"
  defp surface_description(:email), do: "Email inboxes and threads"
  defp surface_description(:chat), do: "Web chat and messaging"
  defp surface_description(:whatsapp), do: "WhatsApp Business API"
  defp surface_description(:custom), do: "Custom channel integrations"

  defp autonomy_level_index(:shadow), do: 0
  defp autonomy_level_index(:draft), do: 1
  defp autonomy_level_index(:execute), do: 2
  defp autonomy_level_index(:autopilot), do: 3
  defp autonomy_level_index(_), do: 1

  defp autonomy_label(:shadow), do: "Shadow"
  defp autonomy_label(:draft), do: "Draft"
  defp autonomy_label(:execute), do: "Execute"
  defp autonomy_label(:autopilot), do: "Autopilot"
  defp autonomy_label(_), do: "Draft"

  defp autonomy_description(:shadow), do: "Observes only, no actions"
  defp autonomy_description(:draft), do: "Prepares actions for approval"
  defp autonomy_description(:execute), do: "Acts with human oversight"
  defp autonomy_description(:autopilot), do: "Fully autonomous operation"
  defp autonomy_description(_), do: "Prepares actions for approval"

  defp highest_autonomy_level([]), do: :draft

  defp highest_autonomy_level(agents) do
    agents
    |> Enum.map(& &1.autonomy_level)
    |> Enum.max_by(&autonomy_level_index/1, fn -> :draft end)
  end

  defp health_label(:healthy), do: "All connections healthy"
  defp health_label(:warning), do: "Connection warning"
  defp health_label(:error), do: "Connection error"
  defp health_label(:no_data), do: "No connections"
  defp health_label(_), do: "Unknown"

  defp endpoints_preview(endpoints) do
    shown = Enum.take(endpoints, 2)
    extra = max(length(endpoints) - 2, 0)
    {shown, extra}
  end

  defp endpoint_connections(connections, endpoint_id) do
    Enum.filter(connections, fn c -> c.endpoint_id == endpoint_id end)
  end

  defp endpoint_status_color(:active), do: "success"
  defp endpoint_status_color(:error), do: "error"
  defp endpoint_status_color(_), do: "warning"

  defp connection_status_color(:active), do: "success"
  defp connection_status_color(:error), do: "error"
  defp connection_status_color(:revoked), do: "error"
  defp connection_status_color(:disabled), do: "warning"
  defp connection_status_color(_), do: "info"

  defp provider_label(connection) do
    label =
      connection.metadata
      |> Kernel.||(%{})
      |> Map.get("provider_label")

    case {connection.provider, label} do
      {:gmail, _} -> "Gmail"
      {:outlook, _} -> "Outlook"
      {:imap, value} when is_binary(value) and value != "" -> value
      {:imap, _} -> "IMAP"
      {provider, _} -> provider |> to_string() |> String.capitalize()
    end
  end

  defp reload_data(socket) do
    tenant = socket.assigns.current_scope.tenant
    surfaces = Channels.unified_surfaces_view(tenant.id)
    connections = Channels.list_connections(tenant.id) |> Repo.preload([:channel, :endpoint])
    stats = compute_aggregate_stats(surfaces)

    socket
    |> assign(:surfaces, surfaces)
    |> assign(:stats, stats)
    |> assign(:connections, connections)
    |> assign(:connections_by_provider, Enum.group_by(connections, & &1.provider))
  end

  defp imap_preset_from_params(%{"preset" => "zoho"}), do: :zoho
  defp imap_preset_from_params(_params), do: :custom

  defp maybe_put_provider_label(params, nil), do: params
  defp maybe_put_provider_label(params, ""), do: params

  defp maybe_put_provider_label(params, label) do
    Map.put_new(params, "provider_label", label)
  end

  defp get_agent_assignments_for_channel(tenant_id, channel_id) do
    Agents.list_agent_channels_for_channel(tenant_id, channel_id)
    |> Repo.preload(:agent)
  end

  defp endpoint_type_label(endpoint) do
    case endpoint.channel do
      %{type: :voice} -> "Voice endpoint"
      %{type: :email} -> "Email endpoint"
      %{type: :chat} -> "Chat endpoint"
      %{type: :whatsapp} -> "WhatsApp endpoint"
      %{type: :custom} -> "Custom endpoint"
      _ -> "Endpoint"
    end
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(%DateTime{} = dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :second)

    cond do
      diff < 60 -> "Just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> Calendar.strftime(dt, "%b %d, %Y %H:%M")
    end
  end

  defp agent_avatar_class(name) do
    colors = [
      "bg-blue-100 text-blue-700",
      "bg-green-100 text-green-700",
      "bg-purple-100 text-purple-700",
      "bg-amber-100 text-amber-700",
      "bg-rose-100 text-rose-700",
      "bg-cyan-100 text-cyan-700",
      "bg-indigo-100 text-indigo-700",
      "bg-emerald-100 text-emerald-700"
    ]

    index = :erlang.phash2(name, length(colors))
    Enum.at(colors, index)
  end

  defp agent_initial(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.first()
    |> Kernel.||("?")
    |> String.upcase()
  end

  defp agent_initial(_), do: "?"

  defp scope_label(%{"mode" => "all"}), do: "All endpoints"
  defp scope_label(%{"mode" => "specific"}), do: "Specific endpoints"
  defp scope_label(_), do: "All endpoints"
end
