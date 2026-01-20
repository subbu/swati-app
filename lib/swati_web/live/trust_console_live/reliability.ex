defmodule SwatiWeb.TrustConsoleLive.Reliability do
  use SwatiWeb, :live_view

  alias Swati.Trust

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    tools = Trust.tool_reliability(tenant.id)
    channels = Trust.channel_health(tenant.id)

    {:ok,
     socket
     |> assign(:tools, tools)
     |> assign(:channels, channels)
     |> assign(:active_tab, :reliability)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="trust-reliability" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div>
            <h1 class="text-xl font-semibold text-foreground">Reliability View</h1>
            <p class="text-sm text-foreground-soft">Tool health and channel status.</p>
          </div>
        </header>

        <nav class="flex flex-wrap items-center gap-2 text-sm">
          <.link patch={~p"/trust"} class={nav_class(@active_tab == :timeline)}>
            Timeline
          </.link>
          <.link patch={~p"/trust/policy"} class={nav_class(@active_tab == :policy)}>
            Policy
          </.link>
          <.link patch={~p"/trust/reliability"} class={nav_class(@active_tab == :reliability)}>
            Reliability
          </.link>
        </nav>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,320px)]">
          <div class="rounded-base border border-base bg-base p-4">
            <div class="flex items-center justify-between">
              <h2 class="text-sm font-semibold text-foreground">Tool failure rates</h2>
              <.badge size="xs" variant="soft" color="info">{length(@tools)} tools</.badge>
            </div>
            <div class="mt-3 overflow-x-auto">
              <.table id="trust-reliability-tools">
                <.table_head class="text-foreground-soft">
                  <:col>Tool</:col>
                  <:col class="text-right">Calls</:col>
                  <:col class="text-right">Errors</:col>
                  <:col class="text-right">Error rate</:col>
                </.table_head>
                <.table_body>
                  <.table_row :for={tool <- @tools}>
                    <:cell class="font-medium text-foreground">{tool.name}</:cell>
                    <:cell class="text-right text-foreground-soft">{tool.total}</:cell>
                    <:cell class="text-right text-foreground-soft">{tool.errors}</:cell>
                    <:cell class="text-right text-foreground-soft">
                      {format_rate(tool.error_rate)}
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>
          </div>

          <div class="rounded-base border border-base bg-base p-4">
            <h2 class="text-sm font-semibold text-foreground">Channels</h2>
            <div class="mt-3 space-y-2">
              <div :for={channel <- @channels} class="flex items-center justify-between">
                <div>
                  <div class="text-sm font-medium text-foreground">{channel.name}</div>
                  <div class="text-xs text-foreground-soft">{channel.key}</div>
                </div>
                <.badge size="sm" variant="soft" color="info">{channel.status}</.badge>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp format_rate(rate) when is_float(rate) do
    percent = Float.round(rate * 100, 1)
    "#{percent}%"
  end

  defp format_rate(_rate), do: "0.0%"

  defp nav_class(true), do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium"
  defp nav_class(false), do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent"
end
