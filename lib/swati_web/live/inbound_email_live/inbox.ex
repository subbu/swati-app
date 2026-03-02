defmodule SwatiWeb.InboundEmailLive.Inbox do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Inbound
  alias SwatiWeb.InboundEmailLive.Components
  alias SwatiWeb.InboundEmailLive.Helpers

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_channels) do
      tenant_id = socket.assigns.current_scope.tenant.id

      {:ok,
       socket
       |> assign(:tenant_id, tenant_id)
       |> assign(:agents, Agents.list_agents(tenant_id))
       |> assign(:filters, default_filters())
       |> assign(:selected_message_id, nil)
       |> assign(:selected_message, nil)
       |> assign(:inbound_enabled, Inbound.enabled?())
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
  def handle_event("filter", params, socket) do
    # Handle phx-change from the search form (no "filters" wrapper)
    filters =
      socket.assigns.filters
      |> Map.merge(params)
      |> normalize_filters()

    {:noreply, socket |> assign(:filters, filters) |> load_data()}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, default_filters())
     |> load_data()}
  end

  @impl true
  def handle_event("select_message", %{"id" => id}, socket) do
    message = Enum.find(socket.assigns.messages, &(to_string(&1.id) == id))

    {:noreply,
     socket
     |> assign(:selected_message_id, id)
     |> assign(:selected_message, message)}
  end

  @impl true
  def handle_event("deselect_message", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_message_id, nil)
     |> assign(:selected_message, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <Components.page_header active_tab="inbox" inbound_enabled={@inbound_enabled} />

        <%!-- Master-detail layout --%>
        <section class="rounded-lg border border-base overflow-hidden">
          <%!-- Filter bar — sessions-style --%>
          <div class="flex flex-wrap items-center gap-2 px-4 py-3 border-b border-base">
            <.form
              for={to_form(@filters, as: :filters)}
              id="inbox-filter"
              phx-change="filter"
              class="flex items-center gap-2"
            >
              <.input
                name="filters[query]"
                value={@filters["query"]}
                type="text"
                placeholder="Search messages"
                phx-debounce="300"
                class="min-w-[16rem] lg:min-w-[20rem]"
              >
                <:inner_prefix>
                  <.icon name="hero-magnifying-glass" class="icon" />
                </:inner_prefix>
              </.input>
            </.form>

            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-arrows-right-left" class="icon" />
                  <span class="hidden lg:inline ml-1">
                    {direction_filter_label(@filters)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"direction" => ""}})}>
                All directions
              </.dropdown_button>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"direction" => "inbound"}})}>
                Inbound
              </.dropdown_button>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"direction" => "outbound"}})}>
                Outbound
              </.dropdown_button>
            </.dropdown>

            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-user-circle" class="icon" />
                  <span class="hidden lg:inline ml-1">
                    {agent_filter_label(@filters, @agents)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"agent_id" => ""}})}>
                All agents
              </.dropdown_button>
              <.dropdown_button
                :for={agent <- @agents}
                phx-click={JS.push("filter", value: %{filters: %{"agent_id" => to_string(agent.id)}})}
              >
                {agent.name}
              </.dropdown_button>
            </.dropdown>

            <%= if has_active_filters?(@filters) do %>
              <.button
                size="xs"
                variant="ghost"
                type="button"
                phx-click="reset_filters"
                aria-label="Reset filters"
              >
                <.icon name="hero-x-mark" class="icon" />
                <span class="hidden lg:inline ml-1">Reset</span>
              </.button>
            <% end %>
          </div>

          <%= if @messages == [] do %>
            <Components.empty_state
              icon="hero-inbox"
              title="No messages"
              description="No email messages match your current filters."
            />
          <% else %>
            <div class="flex" style="height: calc(100vh - 340px); min-height: 400px;">
              <%!-- Left panel: message list --%>
              <div class={[
                "flex-shrink-0 border-r border-base overflow-y-auto",
                "w-full lg:w-[380px] xl:w-[420px]",
                if(@selected_message, do: "hidden lg:block", else: "block")
              ]}>
                <div class="sticky top-0 bg-base border-b border-base px-4 py-2.5 flex items-center justify-between">
                  <span class="text-xs font-medium text-foreground-softer">
                    {length(@messages)} messages
                  </span>
                </div>
                <Components.message_item
                  :for={message <- @messages}
                  message={message}
                  selected={to_string(message.id) == to_string(@selected_message_id)}
                />
              </div>

              <%!-- Right panel: message detail --%>
              <div class={[
                "flex-1 min-w-0 bg-base",
                if(@selected_message, do: "block", else: "hidden lg:block")
              ]}>
                <%= if @selected_message do %>
                  <Components.message_detail
                    message={@selected_message}
                    tenant={@current_scope.tenant}
                    on_close="deselect_message"
                  />
                <% else %>
                  <div class="flex items-center justify-center h-full text-foreground-softer">
                    <div class="text-center">
                      <.icon name="hero-envelope-open" class="size-8 mx-auto mb-2 opacity-40" />
                      <p class="text-sm">Select a message to view details</p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id
    filters = socket.assigns.filters

    messages = Inbound.list_email_messages(tenant_id, limit: 200, filters: filters)

    # If selected message is no longer in the list, deselect it
    selected_id = socket.assigns.selected_message_id
    selected = if selected_id, do: Enum.find(messages, &(to_string(&1.id) == to_string(selected_id)))

    socket
    |> assign(:messages, messages)
    |> assign(:selected_message, selected)
    |> then(fn s -> if is_nil(selected), do: assign(s, :selected_message_id, nil), else: s end)
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

  defp has_active_filters?(filters) do
    filters["direction"] != "" or filters["agent_id"] != "" or filters["case_id"] != ""
  end

  defp direction_filter_label(filters) do
    case filters["direction"] do
      "inbound" -> "Inbound"
      "outbound" -> "Outbound"
      _ -> "Direction"
    end
  end

  defp agent_filter_label(filters, agents) do
    case filters["agent_id"] do
      "" -> "Agent"
      nil -> "Agent"
      agent_id -> Helpers.resolve_agent_name(agent_id, agents) || "Agent"
    end
  end
end
