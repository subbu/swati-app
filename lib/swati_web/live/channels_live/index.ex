defmodule SwatiWeb.ChannelsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Channels
  alias Swati.Channels.Imap
  alias Swati.Repo

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    channels = Channels.list_channels(tenant.id)
    endpoints = Channels.list_endpoints(tenant.id) |> Repo.preload(:channel)
    connections = Channels.list_connections(tenant.id) |> Repo.preload([:channel, :endpoint])
    connections_by_provider = Enum.group_by(connections, & &1.provider)
    imap_defaults = Imap.default_params()

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

    {:ok,
     socket
     |> assign(:channels, channels)
     |> assign(:endpoints, endpoints)
     |> assign(:connections, connections)
     |> assign(:connections_by_provider, connections_by_provider)
     |> assign(:providers, providers)
     |> assign(:sync_providers, Channels.sync_providers())
     |> assign(:imap_sheet_open, false)
     |> assign(:imap_preset, :custom)
     |> assign(:imap_provider_label, Map.get(imap_defaults, "provider_label"))
     |> assign(:imap_form, to_form(Imap.changeset(imap_defaults), as: :imap))}
  end

  @impl true
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
         |> reload_connections()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :imap_form, to_form(changeset, as: :imap))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unable to connect IMAP: #{inspect(reason)}")
         |> assign(:imap_sheet_open, true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div class="flex items-center gap-3">
            <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-sky-400 to-sky-600 text-white shadow">
              <.icon name="hero-adjustments-vertical" class="size-4" />
            </div>
            <div>
              <h1 class="text-xl font-semibold text-foreground">Channels</h1>
              <p class="text-sm text-foreground-soft">Channel registry and endpoints.</p>
            </div>
          </div>
          <div class="flex items-center gap-2 text-sm text-foreground-soft">
            <span class="font-semibold text-foreground">{length(@channels)}</span>
            <span>channels</span>
          </div>
        </header>

        <section class="rounded-base border border-base bg-base p-4">
          <h2 class="text-sm font-semibold text-foreground">Channels</h2>
          <div class="mt-3 overflow-x-auto">
            <.table id="channels-table">
              <.table_head class="text-foreground-soft">
                <:col>Channel</:col>
                <:col>Key</:col>
                <:col>Status</:col>
                <:col>Type</:col>
                <:col class="text-right">Tools</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={channel <- @channels}>
                  <:cell class="font-medium text-foreground">{channel.name}</:cell>
                  <:cell class="text-foreground-soft">{channel.key}</:cell>
                  <:cell>
                    <.badge size="sm" variant="soft" color="info">{channel.status}</.badge>
                  </:cell>
                  <:cell class="text-foreground-soft">{channel.type}</:cell>
                  <:cell class="text-right text-foreground-soft">
                    {length(Map.get(channel.capabilities || %{}, "tools", []))}
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>

        <section class="rounded-base border border-base bg-base p-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold text-foreground">Endpoints</h2>
            <.badge size="xs" variant="soft" color="info">{length(@endpoints)}</.badge>
          </div>
          <div class="mt-3 overflow-x-auto">
            <.table id="endpoints-table">
              <.table_head class="text-foreground-soft">
                <:col>Endpoint</:col>
                <:col>Channel</:col>
                <:col>Status</:col>
                <:col>Display name</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={endpoint <- @endpoints}>
                  <:cell class="font-medium text-foreground">{endpoint.address}</:cell>
                  <:cell class="text-foreground-soft">
                    {if endpoint.channel, do: endpoint.channel.name, else: "—"}
                  </:cell>
                  <:cell>
                    <.badge size="sm" variant="soft" color="info">{endpoint.status}</.badge>
                  </:cell>
                  <:cell class="text-foreground-soft">{endpoint.display_name || "—"}</:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>

        <section class="rounded-base border border-base bg-base p-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-sm font-semibold text-foreground">Connections</h2>
              <p class="text-xs text-foreground-soft">OAuth and channel credentials.</p>
            </div>
            <.dropdown placement="bottom-end">
              <:toggle>
                <.button variant="dashed" size="sm">
                  <.icon name="hero-plus" class="icon" /> Add connection
                </.button>
              </:toggle>
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

          <div id="connection-providers" class="mt-4 grid gap-3 md:grid-cols-2 xl:grid-cols-3">
            <div
              :for={provider <- @providers}
              id={"provider-#{provider.id}"}
              class="rounded-base border border-base bg-base px-4 py-3"
            >
              <% connections = provider_connections(@connections_by_provider, provider.id) %>
              <% status = provider_status(connections) %>
              <% {addresses, extra_count} = provider_address_tags(connections) %>
              <div class="flex items-start justify-between gap-3">
                <div class="flex items-start gap-3">
                  <div class="size-9 flex items-center justify-center rounded-lg bg-radial from-slate-400 to-slate-600 text-white shadow">
                    <.icon name={provider.icon} class="size-4" />
                  </div>
                  <div>
                    <h3 class="text-sm font-semibold text-foreground">{provider.name}</h3>
                    <p class="text-xs text-foreground-soft">{provider.description}</p>
                  </div>
                </div>
                <%= if provider.status == :coming_soon do %>
                  <.badge size="xs" variant="soft" color="warning">Coming soon</.badge>
                <% else %>
                  <.badge size="xs" variant="soft" color={status.color}>{status.label}</.badge>
                <% end %>
              </div>
              <%= if addresses == [] do %>
                <p class="mt-3 text-xs text-foreground-soft">No accounts connected yet.</p>
              <% else %>
                <div class="mt-3 flex flex-wrap items-center gap-1">
                  <span
                    :for={address <- addresses}
                    class="rounded-full border border-base px-2 py-1 text-[11px] text-foreground-soft"
                  >
                    {address}
                  </span>
                  <span
                    :if={extra_count > 0}
                    class="rounded-full border border-base px-2 py-1 text-[11px] text-foreground-soft"
                  >
                    +{extra_count}
                  </span>
                </div>
              <% end %>
              <div class="mt-4 flex items-center justify-between">
                <p class="text-xs text-foreground-soft">
                  <%= if provider.id in @sync_providers do %>
                    {provider_last_sync_label(connections)}
                  <% else %>
                    Sync not available yet.
                  <% end %>
                </p>
                <%= if provider.status == :available and provider.id == :gmail do %>
                  <.link navigate={~p"/channels/gmail/connect"}>
                    <.button size="xs" variant="dashed">
                      {if connections == [], do: "Connect", else: "Add account"}
                    </.button>
                  </.link>
                <% else %>
                  <%= if provider.status == :available and provider.id == :outlook do %>
                    <.link navigate={~p"/channels/outlook/connect"}>
                      <.button size="xs" variant="dashed">
                        {if connections == [], do: "Connect", else: "Add account"}
                      </.button>
                    </.link>
                  <% else %>
                    <%= if provider.status == :available and provider.id == :imap do %>
                      <.button
                        size="xs"
                        variant="dashed"
                        phx-click="open-imap-sheet"
                        phx-value-preset="custom"
                      >
                        {if connections == [], do: "Connect", else: "Add account"}
                      </.button>
                    <% else %>
                      <.button size="xs" variant="ghost" disabled>Connect</.button>
                    <% end %>
                  <% end %>
                <% end %>
              </div>
            </div>
          </div>

          <div class="mt-6 overflow-x-auto">
            <.table id="channel-connections-table">
              <.table_head class="text-foreground-soft">
                <:col>Provider</:col>
                <:col>Endpoint</:col>
                <:col>Status</:col>
                <:col>Last sync</:col>
                <:col class="text-right">Actions</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={connection <- @connections}>
                  <:cell class="font-medium text-foreground">
                    {provider_label(connection)}
                  </:cell>
                  <:cell class="text-foreground-soft">
                    {connection.endpoint && connection.endpoint.address}
                  </:cell>
                  <:cell>
                    <.badge size="sm" variant="soft" color="info">{connection.status}</.badge>
                  </:cell>
                  <:cell class="text-foreground-soft">
                    {if connection.last_synced_at do
                      Calendar.strftime(connection.last_synced_at, "%b %d, %Y %H:%M")
                    else
                      "—"
                    end}
                  </:cell>
                  <:cell class="text-right">
                    <%= if connection.provider in @sync_providers do %>
                      <.button
                        size="xs"
                        variant="ghost"
                        type="button"
                        phx-click="sync_connection"
                        phx-value-id={connection.id}
                      >
                        Sync now
                      </.button>
                    <% else %>
                      <span class="text-xs text-foreground-soft">Sync unavailable</span>
                    <% end %>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>
      </div>

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
    </Layouts.app>
    """
  end

  defp reload_connections(socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    endpoints = Channels.list_endpoints(tenant_id) |> Repo.preload(:channel)
    connections = Channels.list_connections(tenant_id) |> Repo.preload([:channel, :endpoint])

    socket
    |> assign(:endpoints, endpoints)
    |> assign(:connections, connections)
    |> assign(:connections_by_provider, Enum.group_by(connections, & &1.provider))
  end

  defp provider_connections(connections_by_provider, provider) do
    Map.get(connections_by_provider, provider, [])
  end

  defp provider_status(connections) do
    cond do
      connections == [] ->
        %{label: "Not connected", color: "warning"}

      Enum.any?(connections, &(&1.status in [:error, :revoked])) ->
        %{label: "Needs attention", color: "warning"}

      Enum.any?(connections, &(&1.status == :disabled)) ->
        %{label: "Disabled", color: "warning"}

      true ->
        %{label: "Connected", color: "info"}
    end
  end

  defp provider_label(connection) do
    label =
      connection.metadata
      |> Kernel.||(%{})
      |> Map.get("provider_label")

    case {connection.provider, label} do
      {:gmail, _} -> "Gmail"
      {:outlook, _} -> "Outlook"
      {:imap, value} when is_binary(value) and value != "" -> "#{value} (IMAP)"
      {:imap, _} -> "IMAP/SMTP"
      {provider, _} -> provider |> to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end

  defp provider_address_tags(connections) do
    addresses =
      connections
      |> Enum.map(&(&1.endpoint && &1.endpoint.address))
      |> Enum.filter(&is_binary/1)

    {Enum.take(addresses, 2), max(length(addresses) - 2, 0)}
  end

  defp provider_last_sync_label(connections) do
    latest_sync =
      connections
      |> Enum.map(& &1.last_synced_at)
      |> Enum.reject(&is_nil/1)
      |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)

    if latest_sync do
      "Last sync " <> Calendar.strftime(latest_sync, "%b %d, %Y %H:%M")
    else
      "No sync yet."
    end
  end

  defp imap_preset_from_params(%{"preset" => "zoho"}), do: :zoho
  defp imap_preset_from_params(_params), do: :custom

  defp maybe_put_provider_label(params, nil), do: params
  defp maybe_put_provider_label(params, ""), do: params

  defp maybe_put_provider_label(params, label) do
    Map.put_new(params, "provider_label", label)
  end
end
