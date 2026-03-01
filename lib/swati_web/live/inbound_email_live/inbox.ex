defmodule SwatiWeb.InboundEmailLive.Inbox do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Inbound
  alias SwatiWeb.Formatting

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_channels) do
      tenant_id = socket.assigns.current_scope.tenant.id

      {:ok,
       socket
       |> assign(:tenant_id, tenant_id)
       |> assign(:agents, Agents.list_agents(tenant_id))
       |> assign(:filters, default_filters())
       |> load_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(params)
      |> normalize_filters()

    {:noreply, socket |> assign(:filters, filters) |> load_data()}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply, socket |> assign(:filters, default_filters()) |> load_data()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="inbound-email-inbox" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-3 border-b border-base pb-4">
          <div>
            <h1 class="text-2xl font-semibold text-foreground">Email Inbox</h1>
            <p class="text-sm text-foreground-soft">
              Message-level inbox across inbound and outbound email with linked sessions and cases.
            </p>
          </div>
          <div class="flex items-center gap-2">
            <.link navigate={~p"/inbound-email"} class="btn btn-outline btn-sm">Configuration</.link>
            <.button phx-click="clear_filters" variant="ghost" size="xs">Clear filters</.button>
          </div>
        </header>

        <section class="rounded-base border border-base p-4">
          <.form
            for={to_form(@filters, as: :filters)}
            phx-change="filter"
            class="grid gap-3 md:grid-cols-4"
          >
            <.input
              name="filters[query]"
              value={@filters["query"]}
              label="Search"
              placeholder="subject, text, sender, recipient"
            />

            <div class="space-y-1">
              <.label for="filters_direction">Direction</.label>
              <select id="filters_direction" name="filters[direction]" class="select w-full">
                <option value="" selected={@filters["direction"] == ""}>All</option>
                <option value="inbound" selected={@filters["direction"] == "inbound"}>Inbound</option>
                <option value="outbound" selected={@filters["direction"] == "outbound"}>
                  Outbound
                </option>
              </select>
            </div>

            <div class="space-y-1">
              <.label for="filters_agent_id">Owner agent</.label>
              <select id="filters_agent_id" name="filters[agent_id]" class="select w-full">
                <option value="" selected={@filters["agent_id"] == ""}>All</option>
                <option
                  :for={agent <- @agents}
                  value={agent.id}
                  selected={to_string(@filters["agent_id"]) == to_string(agent.id)}
                >
                  {agent.name}
                </option>
              </select>
            </div>

            <.input
              name="filters[case_id]"
              value={@filters["case_id"]}
              label="Case id"
              placeholder="optional case id"
            />
          </.form>
        </section>

        <section class="rounded-base border border-base p-4">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-semibold text-foreground">Messages</h2>
            <.badge size="sm" variant="soft" color="info">{length(@messages)}</.badge>
          </div>

          <div :if={@messages == []} class="mt-3 text-sm text-foreground-soft">
            No messages match current filters.
          </div>

          <div :if={@messages != []} class="mt-3 overflow-x-auto">
            <.table id="inbound-email-inbox-table">
              <.table_head>
                <:col>Time</:col>
                <:col>Direction</:col>
                <:col>Subject</:col>
                <:col>From</:col>
                <:col>To</:col>
                <:col>Owner</:col>
                <:col>Case</:col>
                <:col>Thread</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={message <- @messages}>
                  <:cell>{format_datetime(message.ts, @current_scope.tenant)}</:cell>
                  <:cell>
                    <.badge size="xs" variant="soft" color={direction_color(message.type)}>
                      {direction_label(message.type)}
                    </.badge>
                  </:cell>
                  <:cell class="max-w-xs truncate">{message_subject(message)}</:cell>
                  <:cell class="max-w-[220px] truncate">{message_from(message)}</:cell>
                  <:cell class="max-w-[220px] truncate">{message_to(message)}</:cell>
                  <:cell>{message.agent_name || message.agent_id || "-"}</:cell>
                  <:cell>
                    <.link :if={message.case_id} navigate={~p"/cases/#{message.case_id}"} class="link">
                      {message.case_id}
                    </.link>
                  </:cell>
                  <:cell>
                    <.link navigate={~p"/sessions/#{message.session_id}"} class="link">
                      {message.session_external_id || message.session_id}
                    </.link>
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

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id
    filters = socket.assigns.filters

    assign(
      socket,
      :messages,
      Inbound.list_email_messages(tenant_id, limit: 200, filters: filters)
    )
  end

  defp default_filters do
    %{
      "query" => "",
      "direction" => "",
      "agent_id" => "",
      "case_id" => ""
    }
  end

  defp normalize_filters(filters) do
    filters
    |> Map.new(fn {key, value} -> {to_string(key), normalize_value(value)} end)
    |> Map.merge(default_filters(), fn _key, current, _default -> current end)
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(value), do: to_string(value)

  defp message_subject(message) do
    payload = message.payload || %{}
    payload["subject"] || payload[:subject] || "(no subject)"
  end

  defp message_from(message) do
    payload = message.payload || %{}
    payload["from"] || payload[:from] || "-"
  end

  defp message_to(message) do
    payload = message.payload || %{}
    to = payload["to"] || payload[:to] || []
    List.wrap(to) |> Enum.join(", ")
  end

  defp direction_label("channel.message.received"), do: "Inbound"
  defp direction_label("channel.message.sent"), do: "Outbound"
  defp direction_label(_), do: "Message"

  defp direction_color("channel.message.received"), do: "success"
  defp direction_color("channel.message.sent"), do: "info"
  defp direction_color(_), do: "neutral"

  defp format_datetime(nil, _tenant), do: "-"
  defp format_datetime(%DateTime{} = ts, tenant), do: Formatting.datetime(ts, tenant)
end
