defmodule SwatiWeb.InboundEmailLive.Components do
  use SwatiWeb, :html

  alias Swati.Inbound
  alias SwatiWeb.InboundEmailLive.Helpers

  attr :socket_assigns, :map, required: true

  def page(assigns) do
    assigns = assigns.socket_assigns

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <header class="flex items-center justify-between border-b border-base pb-4">
          <div>
            <h1 class="text-2xl font-semibold text-foreground">Inbound Email</h1>
            <p class="text-sm text-foreground-soft">
              Connect providers, route by agent rules, inspect deliveries, and trace linked sessions/cases.
            </p>
          </div>

          <div class="flex items-center gap-2">
            <.link navigate={~p"/inbound-email/inbox"} class="btn btn-outline btn-sm">
              Email inbox
            </.link>
            <.button variant="soft" phx-click="refresh">
              <.icon name="hero-arrow-path" class="icon" /> Refresh
            </.button>
          </div>
        </header>

        <div
          :if={!@inbound_enabled}
          class="rounded-base border border-warning/40 bg-warning/10 p-3 text-sm"
        >
          Inbound connectors disabled: `inbound_connectors_v1` flag is off; webhook endpoint returns 404.
        </div>

        <section class="grid gap-4 lg:grid-cols-2">
          <article class="rounded-base border border-base p-4 space-y-4">
            <h2 class="text-lg font-semibold text-foreground">Create Connector</h2>

            <.form
              for={to_form(@connector_form, as: :connector)}
              phx-submit="create_connector"
              class="space-y-3"
            >
              <.input name="connector[name]" value={@connector_form["name"]} label="Name" required />
              <.input
                name="connector[default_endpoint_address]"
                value={@connector_form["default_endpoint_address"]}
                label="Default endpoint address"
                placeholder="support@swati.ai"
              />

              <div class="space-y-1">
                <.label for="connector_default_agent_id">Default owner agent</.label>
                <select
                  id="connector_default_agent_id"
                  name="connector[default_agent_id]"
                  class="select w-full"
                >
                  <option
                    :for={{label, value} <- Helpers.agent_options(@agents)}
                    value={value}
                    selected={
                      to_string(@connector_form["default_agent_id"] || "") == to_string(value)
                    }
                  >
                    {label}
                  </option>
                </select>
              </div>

              <.input
                name="connector[signing_secret]"
                type="password"
                value={@connector_form["signing_secret"]}
                label="Resend signing secret"
                required
              />

              <div class="flex justify-end">
                <.button type="submit" variant="solid">Create connector</.button>
              </div>
            </.form>
          </article>

          <article class="rounded-base border border-base p-4 space-y-4">
            <h2 class="text-lg font-semibold text-foreground">Add Agent Rule</h2>

            <.form for={to_form(@rule_form, as: :rule)} phx-submit="create_rule" class="space-y-3">
              <.input name="rule[name]" value={@rule_form["name"]} label="Rule name" required />
              <div class="space-y-1">
                <.label for="rule_agent_id">Owner agent</.label>
                <select id="rule_agent_id" name="rule[agent_id]" class="select w-full" required>
                  <option
                    :for={{label, value} <- Helpers.agent_options(@agents)}
                    value={value}
                    selected={to_string(@rule_form["agent_id"] || "") == to_string(value)}
                  >
                    {label}
                  </option>
                </select>
              </div>

              <div class="grid gap-3 md:grid-cols-2">
                <.input
                  name="rule[priority]"
                  type="number"
                  value={@rule_form["priority"]}
                  label="Priority"
                />
                <div class="space-y-1">
                  <.label for="rule_action">Action</.label>
                  <select id="rule_action" name="rule[action]" class="select w-full">
                    <option value="owner" selected={@rule_form["action"] == "owner"}>Owner</option>
                    <option value="watcher" selected={@rule_form["action"] == "watcher"}>
                      Watcher
                    </option>
                    <option value="silent" selected={@rule_form["action"] == "silent"}>Silent</option>
                  </select>
                </div>
              </div>

              <.input
                name="rule[to_addresses]"
                value={@rule_form["to_addresses"]}
                label="To addresses (comma separated)"
              />
              <.input
                name="rule[to_domains]"
                value={@rule_form["to_domains"]}
                label="To domains (comma separated)"
              />
              <.input
                name="rule[subject_contains]"
                value={@rule_form["subject_contains"]}
                label="Subject contains"
              />

              <div class="flex justify-end">
                <.button type="submit" variant="solid">Add rule</.button>
              </div>
            </.form>
          </article>
        </section>

        <section class="rounded-base border border-base p-4 space-y-4">
          <h2 class="text-lg font-semibold text-foreground">Address Bindings</h2>
          <p class="text-sm text-foreground-soft">
            Exact `to` address owner mapping, evaluated before rules.
          </p>

          <.form
            for={to_form(@binding_form, as: :binding)}
            phx-submit="create_binding"
            class="grid gap-3 md:grid-cols-3"
          >
            <.input
              name="binding[address]"
              value={@binding_form["address"]}
              label="Address"
              placeholder="support@swati.ai"
              required
            />
            <div class="space-y-1">
              <.label for="binding_owner_agent_id">Owner agent</.label>
              <select id="binding_owner_agent_id" name="binding[owner_agent_id]" class="select w-full">
                <option
                  :for={{label, value} <- Helpers.agent_options(@agents)}
                  value={value}
                  selected={to_string(@binding_form["owner_agent_id"] || "") == to_string(value)}
                >
                  {label}
                </option>
              </select>
            </div>
            <div class="flex items-end">
              <.button type="submit" variant="solid">Save binding</.button>
            </div>
          </.form>

          <%= if @bindings == [] do %>
            <p class="text-sm text-foreground-soft">No email address bindings yet.</p>
          <% else %>
            <.table id="inbound-bindings-table">
              <.table_head>
                <:col>Address</:col>
                <:col>Owner</:col>
                <:col>Status</:col>
                <:col></:col>
              </.table_head>
              <.table_body>
                <.table_row :for={binding <- @bindings}>
                  <:cell>{binding.address}</:cell>
                  <:cell>{Helpers.binding_owner_name(binding, @agents)}</:cell>
                  <:cell>{binding.status}</:cell>
                  <:cell>
                    <.button
                      variant="ghost"
                      size="xs"
                      phx-click="clear_binding"
                      phx-value-endpoint_id={binding.id}
                    >
                      Clear owner
                    </.button>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>

        <section class="rounded-base border border-base p-4 space-y-3">
          <h2 class="text-lg font-semibold text-foreground">Connectors</h2>
          <%= if @connectors == [] do %>
            <p class="text-sm text-foreground-soft">No connectors yet.</p>
          <% else %>
            <div class="space-y-3">
              <article
                :for={connector <- @connectors}
                class="rounded-lg border border-base p-3 space-y-2"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <div class="font-medium text-foreground">{connector.name}</div>
                    <div class="text-xs text-foreground-soft">Provider: {connector.provider}</div>
                  </div>
                  <.button
                    variant="ghost"
                    size="xs"
                    phx-click="delete_connector"
                    phx-value-id={connector.id}
                    data-confirm="Delete this connector?"
                  >
                    Delete
                  </.button>
                </div>

                <div class="text-xs text-foreground-soft">Webhook URL</div>
                <code class="block rounded bg-base-200 px-2 py-1 text-xs break-all">
                  {Inbound.webhook_url(connector)}
                </code>

                <form phx-submit="update_connector_secret" class="flex flex-wrap items-end gap-2">
                  <input type="hidden" name="connector_id" value={connector.id} />
                  <.input
                    name="signing_secret"
                    type="password"
                    label="Update signing secret"
                    placeholder="whsec_..."
                  />
                  <.button type="submit" size="xs" variant="soft">Save secret</.button>
                </form>
              </article>
            </div>
          <% end %>
        </section>

        <section class="rounded-base border border-base p-4 space-y-3">
          <h2 class="text-lg font-semibold text-foreground">Inbound Rules</h2>
          <%= if @rules == [] do %>
            <p class="text-sm text-foreground-soft">No rules configured.</p>
          <% else %>
            <div class="space-y-2">
              <article :for={rule <- @rules} class="rounded-lg border border-base p-3">
                <div class="flex items-start justify-between gap-3">
                  <div class="space-y-1">
                    <div class="font-medium text-foreground">{rule.name}</div>
                    <div class="text-xs text-foreground-soft">
                      {rule.action} · priority {rule.priority} · agent {rule.agent && rule.agent.name}
                    </div>
                    <div class="text-xs text-foreground-soft break-all">
                      predicates: {inspect(rule.predicates || %{})}
                    </div>
                  </div>

                  <.button
                    variant="ghost"
                    size="xs"
                    phx-click="delete_rule"
                    phx-value-id={rule.id}
                    data-confirm="Delete this rule?"
                  >
                    Delete
                  </.button>
                </div>
              </article>
            </div>
          <% end %>
        </section>

        <section class="rounded-base border border-base p-4 space-y-3">
          <h2 class="text-lg font-semibold text-foreground">Route Preview</h2>

          <.form
            for={to_form(@route_preview_form, as: :route_preview)}
            phx-submit="preview_route"
            class="grid gap-3 lg:grid-cols-3"
          >
            <div class="space-y-1">
              <.label for="route_preview_connector_id">Connector</.label>
              <select
                id="route_preview_connector_id"
                name="route_preview[connector_id]"
                class="select w-full"
              >
                <option value="">Select connector</option>
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
              placeholder="customer@example.net"
            />
            <.input
              name="route_preview[to]"
              value={@route_preview_form["to"]}
              label="To (comma separated)"
              placeholder="support@swati.ai"
            />
            <.input
              name="route_preview[subject]"
              value={@route_preview_form["subject"]}
              label="Subject"
            />
            <.input
              name="route_preview[message_id]"
              value={@route_preview_form["message_id"]}
              label="Message ID"
            />
            <.input
              name="route_preview[in_reply_to]"
              value={@route_preview_form["in_reply_to"]}
              label="In-Reply-To"
            />
            <.input
              name="route_preview[references]"
              value={@route_preview_form["references"]}
              label="References (comma separated)"
            />
            <div class="flex items-end">
              <.button type="submit" variant="soft">Preview route</.button>
            </div>
          </.form>

          <%= if @route_preview_result do %>
            <article class="rounded-lg border border-base p-3 space-y-1 text-sm">
              <div>
                owner: {Helpers.preview_owner_name(
                  @route_preview_result.route.owner_agent_id,
                  @agents
                )} · reason: {@route_preview_result.route.route_reason}
              </div>
              <div>continuity: {inspect(@route_preview_result.route.continuity)}</div>
              <div>
                watcher agents: {inspect(@route_preview_result.route.watcher_agent_ids || [])}
              </div>
              <div>matched rules: {inspect(@route_preview_result.route.matched_rule_ids || [])}</div>
              <div>thread key: {@route_preview_result.route.thread_key}</div>
            </article>
          <% end %>
        </section>

        <section class="rounded-base border border-base p-4 space-y-3">
          <h2 class="text-lg font-semibold text-foreground">Recent Deliveries</h2>

          <%= if @deliveries == [] do %>
            <p class="text-sm text-foreground-soft">No inbound deliveries yet.</p>
          <% else %>
            <.table id="inbound-deliveries-table">
              <.table_head>
                <:col>Status</:col>
                <:col>Received</:col>
                <:col>From</:col>
                <:col>To</:col>
                <:col>Subject</:col>
                <:col>Owner</:col>
                <:col>Route</:col>
                <:col>Continuity</:col>
                <:col>Session</:col>
                <:col>Case</:col>
                <:col></:col>
              </.table_head>
              <.table_body>
                <.table_row :for={delivery <- @deliveries}>
                  <:cell>
                    <.badge
                      size="sm"
                      variant="soft"
                      color={Helpers.delivery_status_color(delivery.status)}
                    >
                      {delivery.status}
                    </.badge>
                  </:cell>
                  <:cell>{Helpers.format_datetime(delivery.received_at)}</:cell>
                  <:cell>{Helpers.delivery_from(delivery)}</:cell>
                  <:cell>{Helpers.delivery_to(delivery)}</:cell>
                  <:cell>{Helpers.delivery_subject(delivery)}</:cell>
                  <:cell>{Helpers.delivery_owner_agent_id(delivery)}</:cell>
                  <:cell>{Helpers.delivery_route_reason(delivery)}</:cell>
                  <:cell>{Helpers.delivery_continuity(delivery)}</:cell>
                  <:cell>
                    <.link
                      :if={Helpers.delivery_session_id(delivery)}
                      navigate={~p"/sessions/#{Helpers.delivery_session_id(delivery)}"}
                      class="link"
                    >
                      {Helpers.delivery_session_id(delivery)}
                    </.link>
                  </:cell>
                  <:cell>
                    <.link
                      :if={Helpers.delivery_case_id(delivery)}
                      navigate={~p"/cases/#{Helpers.delivery_case_id(delivery)}"}
                      class="link"
                    >
                      {Helpers.delivery_case_id(delivery)}
                    </.link>
                  </:cell>
                  <:cell>
                    <.button
                      :if={Helpers.delivery_replayable?(delivery)}
                      variant="ghost"
                      size="xs"
                      phx-click="replay_delivery"
                      phx-value-id={delivery.id}
                    >
                      Replay
                    </.button>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>

        <section class="rounded-base border border-base p-4 space-y-3">
          <h2 class="text-lg font-semibold text-foreground">Email Threads</h2>

          <%= if @email_sessions == [] do %>
            <p class="text-sm text-foreground-soft">No email sessions yet.</p>
          <% else %>
            <.table id="email-threads-table">
              <.table_head>
                <:col>Thread</:col>
                <:col>Customer</:col>
                <:col>Endpoint</:col>
                <:col>Owner</:col>
                <:col>Case</:col>
                <:col>Last activity</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={session <- @email_sessions}>
                  <:cell>
                    <.link navigate={~p"/sessions/#{session.id}"} class="link">
                      {session.external_id || session.id}
                    </.link>
                  </:cell>
                  <:cell>{session.customer && session.customer.primary_email}</:cell>
                  <:cell>{session.endpoint && session.endpoint.address}</:cell>
                  <:cell>{session.agent && session.agent.name}</:cell>
                  <:cell>
                    <.link :if={session.case_id} navigate={~p"/cases/#{session.case_id}"} class="link">
                      {session.case_id}
                    </.link>
                  </:cell>
                  <:cell>
                    {Helpers.format_datetime(session.last_event_at || session.inserted_at)}
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
