defmodule SwatiWeb.TrustConsoleLive.Policy do
  use SwatiWeb, :live_view

  alias Swati.Channels
  alias Swati.Tools

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    tools = Tools.list_tools(tenant.id)
    channels = Channels.list_channels(tenant.id)

    {:ok,
     socket
     |> assign(:tools, tools)
     |> assign(:channels, channels)
     |> assign(:tenant_policy_json, Jason.encode!(tenant.policy || %{}, pretty: true))
     |> assign(:active_tab, :policy)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="trust-policy" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div>
            <h1 class="text-xl font-semibold text-foreground">Policy View</h1>
            <p class="text-sm text-foreground-soft">Effective policy layers for governance.</p>
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
          <.link patch={~p"/trust/rejections"} class={nav_class(@active_tab == :rejections)}>
            Rejections
          </.link>
        </nav>

        <section class="grid gap-6 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
          <div class="rounded-base border border-base bg-base p-4">
            <h2 class="text-sm font-semibold text-foreground">Tenant policy</h2>
            <pre
              phx-no-curly-interpolation
              class="mt-3 text-xs text-foreground-soft bg-accent/40 rounded-base p-3 overflow-auto"
            ><%= @tenant_policy_json %></pre>
          </div>

          <div class="rounded-base border border-base bg-base p-4">
            <h2 class="text-sm font-semibold text-foreground">Channels</h2>
            <div class="mt-3 overflow-x-auto">
              <.table id="trust-policy-channels">
                <.table_head class="text-foreground-soft">
                  <:col>Channel</:col>
                  <:col>Status</:col>
                  <:col>Channel tools</:col>
                  <:col class="text-right">Tools</:col>
                </.table_head>
                <.table_body>
                  <.table_row :for={channel <- @channels}>
                    <:cell class="font-medium text-foreground">{channel.name}</:cell>
                    <:cell>
                      <.badge size="sm" variant="soft" color="info">
                        {channel.status}
                      </.badge>
                    </:cell>
                    <:cell class="text-foreground-soft">
                      {channel_tools_label(channel)}
                    </:cell>
                    <:cell class="text-right text-foreground-soft">
                      {length(Map.get(channel.capabilities || %{}, "tools", []))}
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>
          </div>
        </section>

        <section class="rounded-base border border-base bg-base p-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold text-foreground">Tool registry</h2>
            <.badge size="xs" variant="soft" color="info">{length(@tools)} tools</.badge>
          </div>
          <div class="mt-3 overflow-x-auto">
            <.table id="trust-policy-tools">
              <.table_head class="text-foreground-soft">
                <:col>Tool</:col>
                <:col>Origin</:col>
                <:col>Access</:col>
                <:col>Financial</:col>
                <:col>PII</:col>
                <:col>Approval</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={tool <- @tools}>
                  <:cell class="font-medium text-foreground">{tool.name}</:cell>
                  <:cell class="text-foreground-soft">{tool.origin}</:cell>
                  <:cell class="text-foreground-soft">{tool.risk["access"]}</:cell>
                  <:cell class="text-foreground-soft">{tool.risk["financial"]}</:cell>
                  <:cell class="text-foreground-soft">{tool.risk["pii"]}</:cell>
                  <:cell class="text-foreground-soft">
                    {if tool.risk["requires_approval"], do: "yes", else: "no"}
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp nav_class(true), do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium"
  defp nav_class(false), do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent"

  defp channel_tools_label(channel) do
    tools = Map.get(channel.capabilities || %{}, "tools", [])

    tools
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> "—"
      items -> Enum.join(items, ", ")
    end
  end
end
