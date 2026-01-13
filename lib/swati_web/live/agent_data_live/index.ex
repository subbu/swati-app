defmodule SwatiWeb.AgentDataLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Integrations
  alias Swati.Integrations.Integration
  alias Swati.Webhooks
  alias Swati.Webhooks.Webhook

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-12">
        <%!-- Page Header --%>
        <header class="relative">
          <div class="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-2">
              <div class="flex items-center gap-3">
                <div class="flex h-10 w-10 items-center justify-center rounded-xl bg-gradient-to-br from-primary/20 to-secondary/20 ring-1 ring-primary/10">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5 text-primary"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                    stroke-width="1.5"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M20.25 6.375c0 2.278-3.694 4.125-8.25 4.125S3.75 8.653 3.75 6.375m16.5 0c0-2.278-3.694-4.125-8.25-4.125S3.75 4.097 3.75 6.375m16.5 0v11.25c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125V6.375m16.5 0v3.75m-16.5-3.75v3.75m16.5 0v3.75C20.25 16.153 16.556 18 12 18s-8.25-1.847-8.25-4.125v-3.75m16.5 0c0 2.278-3.694 4.125-8.25 4.125s-8.25-1.847-8.25-4.125"
                    />
                  </svg>
                </div>
                <h1 class="text-2xl font-semibold tracking-tight">Agent Data</h1>
              </div>
              <p class="text-sm text-base-content/60 max-w-md">
                Configure external data sources and endpoints your agent can access during conversations.
              </p>
            </div>
            <div class="flex items-center gap-3">
              <.button id="new-integration-button" patch={~p"/integrations/new"} variant="soft">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="mr-2 h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                Integration
              </.button>
              <.button patch={~p"/webhooks/new"}>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="mr-2 h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="2"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                Webhook
              </.button>
            </div>
          </div>
        </header>

        <%!-- Integrations Section --%>
        <section class="space-y-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-base-200/80">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4 text-base-content/70"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"
                  />
                </svg>
              </div>
              <div>
                <h2 class="text-base font-medium">Integrations</h2>
                <p class="text-xs text-base-content/50">MCP servers and external tools</p>
              </div>
            </div>
            <.button
              id="add-integration-button"
              patch={~p"/integrations/new"}
              size="sm"
              variant="ghost"
              class="text-xs"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="mr-1.5 h-3.5 w-3.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Add
            </.button>
          </div>

          <%= if @integrations == [] do %>
            <.empty_state
              icon="link"
              title="No integrations yet"
              description="Connect MCP servers and external tools to extend your agent's capabilities."
              action_label="Add integration"
              action_patch={~p"/integrations/new"}
            />
          <% else %>
            <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
              <.integration_card
                :for={integration <- @integrations}
                integration={integration}
                status_color={status_color(integration.status)}
              />
            </div>
          <% end %>
        </section>

        <%!-- Webhooks Section --%>
        <section class="space-y-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="flex h-8 w-8 items-center justify-center rounded-lg bg-base-200/80">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4 text-base-content/70"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                  stroke-width="1.5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
                  />
                </svg>
              </div>
              <div>
                <h2 class="text-base font-medium">Webhooks</h2>
                <p class="text-xs text-base-content/50">Custom HTTP endpoints as tools</p>
              </div>
            </div>
            <.button patch={~p"/webhooks/new"} size="sm" variant="ghost" class="text-xs">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="mr-1.5 h-3.5 w-3.5"
                fill="none"
                viewBox="0 0 24 24"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Add
            </.button>
          </div>

          <%= if @webhooks == [] do %>
            <.empty_state
              icon="webhook"
              title="No webhooks yet"
              description="Create webhooks to call custom HTTP endpoints from your agent."
              action_label="Add webhook"
              action_patch={~p"/webhooks/new"}
            />
          <% else %>
            <%!-- Tag filter pills --%>
            <%= if @tag_counts != [] do %>
              <div class="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  phx-click="filter_webhooks"
                  phx-value-id="all"
                  class={"inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-all duration-200 " <>
                    if(@selected_tag_id, do: "text-base-content/60 hover:text-base-content hover:bg-base-200/60", else: "bg-base-content text-base-100 shadow-sm")}
                >
                  All
                  <span class={"tabular-nums " <> if(@selected_tag_id, do: "text-base-content/40", else: "text-base-100/70")}>
                    {length(@webhooks)}
                  </span>
                </button>
                <.tag_filter_button
                  :for={%{tag: tag, count: count} <- @tag_counts}
                  tag={tag}
                  count={count}
                  selected={@selected_tag_id == tag.id}
                />
              </div>
            <% end %>

            <%!-- Webhook cards --%>
            <%= if @selected_tag_id do %>
              <%= if @filtered_webhooks == [] do %>
                <p class="py-8 text-center text-sm text-base-content/50">
                  No webhooks with this tag.
                </p>
              <% else %>
                <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  <.webhook_card :for={webhook <- @filtered_webhooks} webhook={webhook} />
                </div>
              <% end %>
            <% else %>
              <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                <.webhook_card :for={webhook <- @webhooks} webhook={webhook} />
              </div>
            <% end %>
          <% end %>
        </section>
      </div>

      <.sheet
        id="integration-form-sheet"
        placement="right"
        class="w-full max-w-4xl"
        open={@integration_sheet_open}
        on_close={JS.push("close-integration-sheet")}
      >
        <%= if @integration_sheet_open do %>
          <.live_component
            module={SwatiWeb.IntegrationsLive.FormComponent}
            id="integration-form-component"
            integration={@integration_form_integration}
            action={@integration_form_action}
            current_scope={@current_scope}
            return_to={~p"/agent-data"}
            return_action={:patch}
          />
        <% end %>
      </.sheet>

      <.sheet
        id="webhook-form-sheet"
        placement="right"
        class="w-full max-w-4xl"
        open={@webhook_sheet_open}
        on_close={JS.push("close-webhook-sheet")}
      >
        <%= if @webhook_sheet_open do %>
          <.live_component
            module={SwatiWeb.WebhooksLive.FormComponent}
            id="webhook-form"
            webhook={@webhook_form_webhook}
            action={@webhook_form_action}
            tool_name_locked={@tool_name_locked}
            current_scope={@current_scope}
            return_to={~p"/agent-data"}
          />
        <% end %>
      </.sheet>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    {:ok,
     socket
     |> assign(:integrations, Integrations.list_integrations(tenant.id))
     |> assign(:integration_sheet_open, false)
     |> assign(:integration_form_action, nil)
     |> assign(:integration_form_integration, nil)
     |> assign(:webhook_sheet_open, false)
     |> assign(:webhook_form_action, nil)
     |> assign(:webhook_form_webhook, nil)
     |> assign(:tool_name_locked, false)
     |> load_webhooks(nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    tenant = socket.assigns.current_scope.tenant

    case socket.assigns.live_action do
      :new_webhook ->
        webhook = %Webhook{}

        {:noreply,
         socket
         |> close_integration_sheet()
         |> assign_webhook_sheet(webhook, :new, false)}

      :edit_webhook ->
        webhook = Webhooks.get_webhook!(tenant.id, params["id"])
        locked = Webhooks.attached?(webhook.id)

        {:noreply,
         socket
         |> close_integration_sheet()
         |> assign_webhook_sheet(webhook, :edit, locked)}

      :new_integration ->
        integration = %Integration{}

        {:noreply,
         socket
         |> close_webhook_sheet()
         |> assign_integration_sheet(integration, :new)}

      _ ->
        {:noreply,
         socket
         |> close_webhook_sheet()
         |> close_integration_sheet()}
    end
  end

  @impl true
  def handle_event("test_integration", %{"id" => id}, socket) do
    integration = Integrations.get_integration!(socket.assigns.current_scope.tenant.id, id)

    case Integrations.test_integration(integration) do
      {:ok, _integration, _tools} ->
        {:noreply,
         socket
         |> put_flash(:info, "Integration connection succeeded.")
         |> refresh_integrations()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Integration connection failed.")
         |> refresh_integrations()}
    end
  end

  @impl true
  def handle_event("test_webhook", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(socket.assigns.current_scope.tenant.id, id)

    case Webhooks.test_webhook(webhook) do
      {:ok, _webhook} ->
        {:noreply,
         socket
         |> put_flash(:info, "Webhook test succeeded.")
         |> refresh_webhooks()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Webhook test failed.")
         |> refresh_webhooks()}
    end
  end

  @impl true
  def handle_event("filter_webhooks", %{"id" => "all"}, socket) do
    {:noreply, load_webhooks(socket, nil)}
  end

  @impl true
  def handle_event("filter_webhooks", %{"id" => tag_id}, socket) do
    {:noreply, load_webhooks(socket, tag_id)}
  end

  @impl true
  def handle_event("close-webhook-sheet", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/agent-data")}
  end

  @impl true
  def handle_event("close-integration-sheet", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/agent-data")}
  end

  @impl true
  def handle_info(:refresh_webhooks, socket) do
    {:noreply, refresh_webhooks(socket)}
  end

  @impl true
  def handle_info(:refresh_integrations, socket) do
    {:noreply, refresh_integrations(socket)}
  end

  # Card component for integrations
  defp integration_card(assigns) do
    ~H"""
    <div class="group relative rounded-xl border border-base-300/60 bg-base-100 p-4 transition-all duration-200 hover:border-base-300 hover:shadow-sm">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <.link
            navigate={~p"/integrations/#{@integration.id}"}
            class="block truncate font-medium text-base-content hover:text-primary transition-colors"
          >
            {@integration.name}
          </.link>
          <p class="mt-0.5 text-xs text-base-content/50">{@integration.type}</p>
        </div>
        <div class={"flex h-2 w-2 rounded-full ring-4 " <> status_ring_class(@status_color)} />
      </div>

      <div class="mt-4 flex items-center justify-between">
        <span class="text-xs text-base-content/40">
          {if @integration.last_test_status, do: @integration.last_test_status, else: "Never tested"}
        </span>
        <div class="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
          <button
            type="button"
            phx-click="test_integration"
            phx-value-id={@integration.id}
            class="rounded-md px-2 py-1 text-xs font-medium text-base-content/60 hover:bg-base-200 hover:text-base-content transition-colors"
          >
            Test
          </button>
          <.link
            navigate={~p"/integrations/#{@integration.id}/edit"}
            class="rounded-md px-2 py-1 text-xs font-medium text-base-content/60 hover:bg-base-200 hover:text-base-content transition-colors"
          >
            Edit
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # Card component for webhooks
  defp webhook_card(assigns) do
    ~H"""
    <div class="group relative rounded-xl border border-base-300/60 bg-base-100 p-4 transition-all duration-200 hover:border-base-300 hover:shadow-sm">
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <.link
            navigate={~p"/webhooks/#{@webhook.id}"}
            class="block truncate font-medium text-base-content hover:text-primary transition-colors"
          >
            {@webhook.name}
          </.link>
          <div class="mt-1 flex items-center gap-2">
            <span class="inline-flex items-center rounded bg-base-200/80 px-1.5 py-0.5 font-mono text-[10px] font-medium text-base-content/70">
              {method_label(@webhook.http_method)}
            </span>
            <span class="truncate text-xs text-base-content/40">{@webhook.tool_name}</span>
          </div>
        </div>
        <div class={"flex h-2 w-2 rounded-full ring-4 " <> status_ring_class(status_color(@webhook.status))} />
      </div>

      <%= if @webhook.tags != [] do %>
        <div class="mt-3 flex flex-wrap gap-1.5">
          <span
            :for={tag <- sort_tags(@webhook.tags)}
            class="inline-flex h-5 items-center gap-1 rounded-badge px-2 text-[11px] font-medium"
            style={tag_badge_style(tag)}
          >
            {tag.name}
          </span>
        </div>
      <% end %>

      <div class="mt-4 flex items-center justify-between">
        <span class="text-xs text-base-content/40">
          {if @webhook.last_test_status, do: @webhook.last_test_status, else: "Never tested"}
        </span>
        <div class="flex items-center gap-1 opacity-0 transition-opacity group-hover:opacity-100">
          <button
            type="button"
            phx-click="test_webhook"
            phx-value-id={@webhook.id}
            class="rounded-md px-2 py-1 text-xs font-medium text-base-content/60 hover:bg-base-200 hover:text-base-content transition-colors"
          >
            Test
          </button>
          <.link
            patch={~p"/webhooks/#{@webhook.id}/edit"}
            class="rounded-md px-2 py-1 text-xs font-medium text-base-content/60 hover:bg-base-200 hover:text-base-content transition-colors"
          >
            Edit
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # Empty state component
  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center rounded-xl border border-dashed border-base-300 bg-base-100/50 px-6 py-12 text-center">
      <div class="flex h-12 w-12 items-center justify-center rounded-full bg-base-200/60">
        <%= case @icon do %>
          <% "link" -> %>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-base-content/40"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M13.19 8.688a4.5 4.5 0 011.242 7.244l-4.5 4.5a4.5 4.5 0 01-6.364-6.364l1.757-1.757m13.35-.622l1.757-1.757a4.5 4.5 0 00-6.364-6.364l-4.5 4.5a4.5 4.5 0 001.242 7.244"
              />
            </svg>
          <% "webhook" -> %>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-base-content/40"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M7.5 21L3 16.5m0 0L7.5 12M3 16.5h13.5m0-13.5L21 7.5m0 0L16.5 12M21 7.5H7.5"
              />
            </svg>
          <% _ -> %>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              class="h-5 w-5 text-base-content/40"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              stroke-width="1.5"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
        <% end %>
      </div>
      <h3 class="mt-4 text-sm font-medium text-base-content/80">{@title}</h3>
      <p class="mt-1 max-w-xs text-xs text-base-content/50">{@description}</p>
      <.button patch={@action_patch} size="sm" variant="soft" class="mt-5">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="mr-1.5 h-3.5 w-3.5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
        </svg>
        {@action_label}
      </.button>
    </div>
    """
  end

  # Tag filter button component
  defp tag_filter_button(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="filter_webhooks"
      phx-value-id={@tag.id}
      class={"inline-flex h-7 items-center gap-1.5 rounded-full px-3 text-xs font-medium transition-all duration-200 " <>
        if(@selected, do: "shadow-sm", else: "hover:opacity-80")}
      style={tag_filter_style(@tag, @selected)}
    >
      {@tag.name}
      <span class="tabular-nums opacity-70">{@count}</span>
    </button>
    """
  end

  defp refresh_integrations(socket) do
    tenant = socket.assigns.current_scope.tenant
    assign(socket, integrations: Integrations.list_integrations(tenant.id))
  end

  defp refresh_webhooks(socket) do
    load_webhooks(socket, socket.assigns.selected_tag_id)
  end

  defp assign_webhook_sheet(socket, webhook, action, locked) do
    socket
    |> assign(:webhook_sheet_open, true)
    |> assign(:webhook_form_action, action)
    |> assign(:webhook_form_webhook, webhook)
    |> assign(:tool_name_locked, locked)
  end

  defp assign_integration_sheet(socket, integration, action) do
    socket
    |> assign(:integration_sheet_open, true)
    |> assign(:integration_form_action, action)
    |> assign(:integration_form_integration, integration)
  end

  defp close_webhook_sheet(socket) do
    socket
    |> assign(:webhook_sheet_open, false)
    |> assign(:webhook_form_action, nil)
    |> assign(:webhook_form_webhook, nil)
    |> assign(:tool_name_locked, false)
  end

  defp close_integration_sheet(socket) do
    socket
    |> assign(:integration_sheet_open, false)
    |> assign(:integration_form_action, nil)
    |> assign(:integration_form_integration, nil)
  end

  defp load_webhooks(socket, tag_id) do
    tenant = socket.assigns.current_scope.tenant
    webhooks = Webhooks.list_webhooks(tenant.id)
    tag_counts = Webhooks.list_tags_with_counts(tenant.id)

    filtered_webhooks =
      if is_nil(tag_id) do
        []
      else
        Webhooks.list_webhooks(tenant.id, tag_id: tag_id)
      end

    socket
    |> assign(:webhooks, webhooks)
    |> assign(:tag_counts, tag_counts)
    |> assign(:selected_tag_id, tag_id)
    |> assign(:filtered_webhooks, filtered_webhooks)
  end

  # Status indicator ring classes
  defp status_ring_class("success"), do: "bg-success ring-success/20"
  defp status_ring_class("warning"), do: "bg-warning ring-warning/20"
  defp status_ring_class(_), do: "bg-base-content/30 ring-base-content/10"

  # Tag badge style for webhook cards (soft style with colored background)
  defp tag_badge_style(tag) do
    bg = color_with_alpha(tag.color, "18")
    "color: #{tag.color}; background-color: #{bg};"
  end

  # Tag filter button style (solid when selected, outline when not)
  defp tag_filter_style(tag, true) do
    # Selected: solid colored background with white/dark text
    "background-color: #{tag.color}; color: #{contrasting_text_color(tag.color)};"
  end

  defp tag_filter_style(tag, false) do
    # Unselected: outline style
    bg = color_with_alpha(tag.color, "12")
    "background-color: #{bg}; color: #{tag.color}; border: 1px solid #{color_with_alpha(tag.color, "30")};"
  end

  defp color_with_alpha(color, alpha) when is_binary(color) do
    if String.starts_with?(color, "#") and String.length(color) == 7 do
      color <> alpha
    else
      "transparent"
    end
  end

  defp color_with_alpha(_color, _alpha), do: "transparent"

  # Simple contrast check - returns white for dark colors, dark for light colors
  defp contrasting_text_color(hex_color) when is_binary(hex_color) do
    case parse_hex_color(hex_color) do
      {:ok, r, g, b} ->
        # Using relative luminance formula
        luminance = 0.299 * r + 0.587 * g + 0.114 * b

        if luminance > 160, do: "#1f2937", else: "#ffffff"

      :error ->
        "#ffffff"
    end
  end

  defp contrasting_text_color(_), do: "#ffffff"

  defp parse_hex_color("#" <> hex) when byte_size(hex) == 6 do
    with {r, ""} <- Integer.parse(String.slice(hex, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(hex, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(hex, 4, 2), 16) do
      {:ok, r, g, b}
    else
      _ -> :error
    end
  end

  defp parse_hex_color(_), do: :error

  # Status color mapping
  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:disabled), do: "warning"
  defp status_color("disabled"), do: "warning"
  defp status_color(_), do: "neutral"

  # HTTP method display
  defp method_label(value) when is_atom(value) do
    value |> Atom.to_string() |> String.upcase()
  end

  defp method_label(value) when is_binary(value) do
    String.upcase(value)
  end

  # Tag sorting
  defp sort_tags(tags) when is_list(tags) do
    Enum.sort_by(tags, &String.downcase(&1.name))
  end

  defp sort_tags(_tags), do: []
end
