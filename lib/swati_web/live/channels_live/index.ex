defmodule SwatiWeb.ChannelsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Channels
  alias Swati.Repo

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    channels = Channels.list_channels(tenant.id)
    endpoints = Channels.list_endpoints(tenant.id) |> Repo.preload(:channel)

    {:ok,
     socket
     |> assign(:channels, channels)
     |> assign(:endpoints, endpoints)}
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
      </div>
    </Layouts.app>
    """
  end
end
