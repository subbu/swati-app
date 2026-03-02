defmodule SwatiWeb.InboundEmailLive.Preview do
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
       |> assign(:connectors, Inbound.list_connectors(tenant_id))
       |> assign(:route_preview_form, form_defaults())
       |> assign(:route_preview_result, nil)
       |> assign(:show_advanced, false)
       |> assign(:inbound_enabled, Inbound.enabled?())}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("preview_route", %{"route_preview" => params}, socket) do
    connector_id = Map.get(params, "connector_id")

    if is_nil(blank_to_nil(connector_id)) do
      {:noreply, put_flash(socket, :error, "Select a connector for route preview.")}
    else
      connector = Inbound.get_connector!(socket.assigns.tenant_id, connector_id)

      case Inbound.preview_route(connector, params) do
        {:ok, result} ->
          {:noreply,
           socket
           |> assign(:route_preview_form, Map.merge(form_defaults(), params))
           |> assign(:route_preview_result, result)}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Route preview failed: #{inspect(reason)}")
           |> assign(:route_preview_result, nil)}
      end
    end
  end

  @impl true
  def handle_event("toggle_advanced", _params, socket) do
    {:noreply, assign(socket, :show_advanced, !socket.assigns.show_advanced)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <Components.page_header active_tab="preview" inbound_enabled={@inbound_enabled} />

        <div class="grid gap-6 lg:grid-cols-2">
          <%!-- Left column: Form --%>
          <div class="space-y-5">
            <div>
              <h2 class="text-base font-semibold text-foreground">Test Email Routing</h2>
              <p class="text-sm text-foreground-softer mt-1">
                Simulate how an email would be routed through your connectors and rules without sending anything.
              </p>
            </div>

            <.form
              for={to_form(@route_preview_form, as: :route_preview)}
              phx-submit="preview_route"
              class="space-y-4"
            >
              <div class="space-y-1.5">
                <.label for="route_preview_connector_id">Connector</.label>
                <select
                  id="route_preview_connector_id"
                  name="route_preview[connector_id]"
                  class="select w-full"
                  required
                >
                  <option value="">Select a connector</option>
                  <option
                    :for={connector <- @connectors}
                    value={connector.id}
                    selected={
                      to_string(@route_preview_form["connector_id"] || "") == to_string(connector.id)
                    }
                  >
                    {connector.name}
                  </option>
                </select>
              </div>

              <.input
                name="route_preview[from]"
                value={@route_preview_form["from"]}
                label="From"
                placeholder="customer@example.com"
              />
              <.input
                name="route_preview[to]"
                value={@route_preview_form["to"]}
                label="To"
                placeholder="support@yourcompany.com"
              />
              <.input
                name="route_preview[subject]"
                value={@route_preview_form["subject"]}
                label="Subject"
                placeholder="Re: Invoice #1234"
              />

              <%!-- Advanced fields (collapsible) --%>
              <div class="border-t border-base pt-3">
                <button
                  type="button"
                  phx-click="toggle_advanced"
                  class="flex items-center gap-1.5 text-sm text-foreground-softer hover:text-foreground transition-colors"
                >
                  <.icon
                    name={if @show_advanced, do: "hero-chevron-down", else: "hero-chevron-right"}
                    class="size-3.5"
                  />
                  Advanced threading fields
                </button>

                <div :if={@show_advanced} class="space-y-4 mt-4">
                  <.input
                    name="route_preview[message_id]"
                    value={@route_preview_form["message_id"]}
                    label="Message-ID"
                    placeholder="<abc@mail.example.com>"
                  />
                  <.input
                    name="route_preview[in_reply_to]"
                    value={@route_preview_form["in_reply_to"]}
                    label="In-Reply-To"
                    placeholder="<def@mail.example.com>"
                  />
                  <.input
                    name="route_preview[references]"
                    value={@route_preview_form["references"]}
                    label="References"
                    placeholder="<ghi@mail.example.com>, <jkl@mail.example.com>"
                  />
                </div>
              </div>

              <.button type="submit" variant="solid" class="w-full">
                <.icon name="hero-play" class="size-4" /> Preview route
              </.button>
            </.form>
          </div>

          <%!-- Right column: Results --%>
          <div>
            <%= if @route_preview_result do %>
              <% route = @route_preview_result.route %>
              <div class="rounded-lg border border-base overflow-hidden">
                <%!-- Result header --%>
                <div class={[
                  "px-5 py-4 border-b",
                  if(route.owner_agent_id, do: "bg-success/5 border-success/20", else: "bg-warning/5 border-warning/20")
                ]}>
                  <div class="flex items-center gap-2">
                    <.icon
                      name={if route.owner_agent_id, do: "hero-check-circle", else: "hero-exclamation-triangle"}
                      class={if route.owner_agent_id, do: "size-5 text-success", else: "size-5 text-warning"}
                    />
                    <span class="font-semibold text-foreground">
                      {if route.owner_agent_id, do: "Successfully routed", else: "No route matched"}
                    </span>
                  </div>
                </div>

                <%!-- Result details --%>
                <div class="p-5 space-y-4">
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Owner</span>
                      <div class="text-sm font-medium text-foreground mt-1">
                        {Helpers.resolve_agent_name(route.owner_agent_id, @agents) || "-"}
                      </div>
                    </div>
                    <div>
                      <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Reason</span>
                      <div class="text-sm text-foreground mt-1">{route.route_reason || "-"}</div>
                    </div>
                  </div>

                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Continuity</span>
                      <div class="flex items-center gap-1.5 mt-1">
                        <% continuity = route.continuity %>
                        <span :if={continuity} class={[
                          "inline-block size-2 rounded-full",
                          if(Map.get(continuity, :hit) || Map.get(continuity, "hit"), do: "bg-success", else: "bg-foreground-softer/40")
                        ]} />
                        <span class="text-sm text-foreground">
                          {cond do
                            is_nil(continuity) -> "-"
                            Map.get(continuity, :hit) || Map.get(continuity, "hit") -> "Hit"
                            true -> "Miss"
                          end}
                        </span>
                      </div>
                    </div>
                    <div>
                      <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Thread key</span>
                      <div class="text-sm text-foreground mt-1 break-all">
                        {route.thread_key || "-"}
                      </div>
                    </div>
                  </div>

                  <div :if={route.watcher_agent_ids && route.watcher_agent_ids != []}>
                    <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Watcher agents</span>
                    <div class="flex flex-wrap gap-1.5 mt-1.5">
                      <.badge
                        :for={watcher_id <- route.watcher_agent_ids}
                        size="sm"
                        variant="soft"
                        color="warning"
                      >
                        {Helpers.resolve_agent_name(watcher_id, @agents) || watcher_id}
                      </.badge>
                    </div>
                  </div>

                  <div :if={route.matched_rule_ids && route.matched_rule_ids != []}>
                    <span class="text-xs font-medium uppercase tracking-wider text-foreground-softer">Matched rules</span>
                    <div class="flex flex-wrap gap-1.5 mt-1.5">
                      <.badge
                        :for={rule_id <- route.matched_rule_ids}
                        size="sm"
                        variant="soft"
                        color="info"
                      >
                        {rule_id}
                      </.badge>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <div class="rounded-lg border border-dashed border-base-300 flex items-center justify-center" style="min-height: 300px;">
                <div class="text-center">
                  <.icon name="hero-beaker" class="size-8 mx-auto mb-2 text-foreground-softer/40" />
                  <p class="text-sm text-foreground-softer">Run a preview to see routing results</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp form_defaults do
    %{
      "connector_id" => "",
      "from" => "",
      "to" => "",
      "subject" => "",
      "message_id" => "",
      "in_reply_to" => "",
      "references" => ""
    }
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value
end
