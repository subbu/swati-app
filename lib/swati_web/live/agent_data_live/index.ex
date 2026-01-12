defmodule SwatiWeb.AgentDataLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Integrations
  alias Swati.Webhooks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Agent data</h1>
            <p class="text-sm text-base-content/70">
              Manage MCP servers and webhooks the agent can call.
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.button navigate={~p"/integrations/new"} variant="soft">New integration</.button>
            <.button navigate={~p"/webhooks/new"}>New webhook</.button>
          </div>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-semibold">Integrations</h2>
              <p class="text-sm text-base-content/70">Connect MCP servers and tools.</p>
            </div>
            <.button navigate={~p"/integrations/new"} size="sm" variant="ghost">
              Add integration
            </.button>
          </div>

          <%= if @integrations == [] do %>
            <p class="text-sm text-base-content/60">No integrations yet.</p>
          <% else %>
            <.table>
              <.table_head>
                <:col>Name</:col>
                <:col>Type</:col>
                <:col>Status</:col>
                <:col>Last test</:col>
                <:col></:col>
              </.table_head>
              <.table_body>
                <.table_row :for={integration <- @integrations}>
                  <:cell class="font-medium">
                    <.link
                      id={"integration-#{integration.id}-link"}
                      navigate={~p"/integrations/#{integration.id}"}
                      class="underline"
                    >
                      {integration.name}
                    </.link>
                  </:cell>
                  <:cell>{integration.type}</:cell>
                  <:cell>
                    <.badge color={status_color(integration.status)} variant="soft">
                      {integration.status}
                    </.badge>
                  </:cell>
                  <:cell>{integration.last_test_status || "—"}</:cell>
                  <:cell class="text-right">
                    <div class="flex items-center justify-end gap-2">
                      <.button
                        size="sm"
                        variant="ghost"
                        phx-click="test_integration"
                        phx-value-id={integration.id}
                      >
                        Test
                      </.button>
                      <.link
                        class="text-sm underline"
                        navigate={~p"/integrations/#{integration.id}/edit"}
                      >
                        Edit
                      </.link>
                    </div>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 class="text-lg font-semibold">Webhooks</h2>
              <p class="text-sm text-base-content/70">Call custom HTTP endpoints as tools.</p>
            </div>
            <.button navigate={~p"/webhooks/new"} size="sm" variant="ghost">
              Add webhook
            </.button>
          </div>

          <%= if @webhooks == [] do %>
            <p class="text-sm text-base-content/60">No webhooks yet.</p>
          <% else %>
            <%= if @tag_counts == [] do %>
              <.webhook_table webhooks={@webhooks} />
            <% else %>
              <div class="flex flex-wrap items-center gap-2">
                <.button
                  size="sm"
                  variant={if(@selected_tag_id, do: "ghost", else: "soft")}
                  phx-click="filter_webhooks"
                  phx-value-id="all"
                >
                  All
                </.button>
                <.button
                  :for={%{tag: tag, count: count} <- @tag_counts}
                  size="sm"
                  variant={if(@selected_tag_id == tag.id, do: "soft", else: "ghost")}
                  phx-click="filter_webhooks"
                  phx-value-id={tag.id}
                  class="flex items-center gap-2"
                >
                  <span class="h-2 w-2 rounded-full" style={tag_dot_style(tag)}></span>
                  {tag.name}
                  <span class="text-xs text-base-content/60">({count})</span>
                </.button>
              </div>

              <%= if @selected_tag_id do %>
                <%= if @filtered_webhooks == [] do %>
                  <p class="text-sm text-base-content/60">No webhooks in this tag yet.</p>
                <% else %>
                  <.webhook_table webhooks={@filtered_webhooks} />
                <% end %>
              <% else %>
                <div class="space-y-6">
                  <div :for={{tag, grouped_webhooks} <- @webhook_groups} class="space-y-3">
                    <div class="flex items-center gap-2">
                      <span
                        class="inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-xs font-medium"
                        style={tag_style(tag)}
                      >
                        <span class="h-1.5 w-1.5 rounded-full" style={tag_dot_style(tag)}></span>
                        {tag.name}
                      </span>
                      <span class="text-xs text-base-content/60">
                        {webhook_count_label(length(grouped_webhooks))}
                      </span>
                    </div>
                    <.webhook_table webhooks={grouped_webhooks} />
                  </div>

                  <div :if={@untagged_webhooks != []} class="space-y-3">
                    <div class="flex items-center gap-2">
                      <span class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                        Untagged
                      </span>
                      <span class="text-xs text-base-content/60">
                        {webhook_count_label(length(@untagged_webhooks))}
                      </span>
                    </div>
                    <.webhook_table webhooks={@untagged_webhooks} />
                  </div>
                </div>
              <% end %>
            <% end %>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    {:ok,
     socket
     |> assign(:integrations, Integrations.list_integrations(tenant.id))
     |> load_webhooks(nil)}
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

  defp webhook_table(assigns) do
    ~H"""
    <.table>
      <.table_head>
        <:col>Name</:col>
        <:col>Method</:col>
        <:col>Status</:col>
        <:col>Last test</:col>
        <:col></:col>
      </.table_head>
      <.table_body>
        <.table_row :for={webhook <- @webhooks}>
          <:cell class="font-medium">
            <.link
              id={"webhook-#{webhook.id}-link"}
              navigate={~p"/webhooks/#{webhook.id}"}
              class="underline"
            >
              {webhook.name}
            </.link>
            <p class="text-xs text-base-content/60">{webhook.tool_name}</p>
            <div :if={webhook.tags != []} class="mt-2 flex flex-wrap gap-1.5">
              <span
                :for={tag <- sort_tags(webhook.tags)}
                class="inline-flex items-center gap-1.5 rounded-full border px-2 py-1 text-[11px] font-medium"
                style={tag_style(tag)}
              >
                <span class="h-1.5 w-1.5 rounded-full" style={tag_dot_style(tag)}></span>
                {tag.name}
              </span>
            </div>
          </:cell>
          <:cell>{method_label(webhook.http_method)}</:cell>
          <:cell>
            <.badge color={status_color(webhook.status)} variant="soft">
              {webhook.status}
            </.badge>
          </:cell>
          <:cell>{webhook.last_test_status || "—"}</:cell>
          <:cell class="text-right">
            <div class="flex items-center justify-end gap-2">
              <.button
                size="sm"
                variant="ghost"
                phx-click="test_webhook"
                phx-value-id={webhook.id}
              >
                Test
              </.button>
              <.link class="text-sm underline" navigate={~p"/webhooks/#{webhook.id}/edit"}>
                Edit
              </.link>
            </div>
          </:cell>
        </.table_row>
      </.table_body>
    </.table>
    """
  end

  defp refresh_integrations(socket) do
    tenant = socket.assigns.current_scope.tenant
    assign(socket, integrations: Integrations.list_integrations(tenant.id))
  end

  defp refresh_webhooks(socket) do
    load_webhooks(socket, socket.assigns.selected_tag_id)
  end

  defp load_webhooks(socket, tag_id) do
    tenant = socket.assigns.current_scope.tenant
    webhooks = Webhooks.list_webhooks(tenant.id)
    tag_counts = Webhooks.list_tags_with_counts(tenant.id)
    {webhook_groups, untagged_webhooks} = group_webhooks(webhooks, tag_counts)

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
    |> assign(:webhook_groups, webhook_groups)
    |> assign(:untagged_webhooks, untagged_webhooks)
    |> assign(:filtered_webhooks, filtered_webhooks)
  end

  defp group_webhooks(webhooks, tag_counts) do
    tag_groups =
      Enum.reduce(webhooks, %{}, fn webhook, acc ->
        Enum.reduce(webhook.tags, acc, fn tag, acc ->
          Map.update(acc, tag.id, [webhook], &[webhook | &1])
        end)
      end)

    groups =
      tag_counts
      |> Enum.map(fn %{tag: tag} ->
        {tag, Enum.reverse(Map.get(tag_groups, tag.id, []))}
      end)
      |> Enum.reject(fn {_tag, grouped_webhooks} -> grouped_webhooks == [] end)

    untagged =
      Enum.filter(webhooks, fn webhook ->
        case webhook.tags do
          [] -> true
          _ -> false
        end
      end)

    {groups, untagged}
  end

  defp sort_tags(tags) when is_list(tags) do
    Enum.sort_by(tags, &String.downcase(&1.name))
  end

  defp sort_tags(_tags), do: []

  defp tag_style(tag) do
    "border-color: #{tag.color}; color: #{tag.color};"
  end

  defp tag_dot_style(tag) do
    "background-color: #{tag.color};"
  end

  defp webhook_count_label(1), do: "1 webhook"
  defp webhook_count_label(count), do: "#{count} webhooks"

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:disabled), do: "warning"
  defp status_color("disabled"), do: "warning"
  defp status_color(_), do: "neutral"

  defp method_label(value) when is_atom(value) do
    value |> Atom.to_string() |> String.upcase()
  end

  defp method_label(value) when is_binary(value) do
    String.upcase(value)
  end
end
