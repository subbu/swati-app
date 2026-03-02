defmodule SwatiWeb.InboundEmailLive.Setup do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Inbound
  alias SwatiWeb.InboundEmailLive.Components
  alias SwatiWeb.InboundEmailLive.Helpers

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_channels) do
      tenant_id = socket.assigns.current_scope.tenant.id

      socket =
        socket
        |> assign(:tenant_id, tenant_id)
        |> assign(:agents, Agents.list_agents(tenant_id))
        |> assign(:connector_form, connector_form_defaults())
        |> assign(:binding_form, binding_form_defaults())
        |> assign(:rule_form, rule_form_defaults())
        |> assign(:inbound_enabled, Inbound.enabled?())
        |> load_data()

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <Components.page_header active_tab="setup" inbound_enabled={@inbound_enabled} />

        <%!-- Connectors Section --%>
        <section class="space-y-4">
          <Components.section_header title="Connectors">
            <:action>
              <.button
                variant="outline"
                size="sm"
                phx-click={Fluxon.open_dialog("add-connector-sheet")}
              >
                <.icon name="hero-plus" class="size-3.5" /> Add connector
              </.button>
            </:action>
          </Components.section_header>

          <%= if @connectors == [] do %>
            <div class="rounded-lg border border-base">
              <Components.empty_state
                icon="hero-inbox-arrow-down"
                title="No connectors configured"
                description="Create your first connector to start receiving inbound email via webhook."
              >
                <:action>
                  <.button
                    variant="solid"
                    size="sm"
                    phx-click={Fluxon.open_dialog("add-connector-sheet")}
                  >
                    <.icon name="hero-plus" class="size-3.5" /> Create connector
                  </.button>
                </:action>
              </Components.empty_state>
            </div>
          <% else %>
            <div class="grid gap-3 lg:grid-cols-2">
              <Components.connector_card
                :for={connector <- @connectors}
                connector={connector}
                agents={@agents}
              />
            </div>
          <% end %>
        </section>

        <%!-- Routing Rules Section --%>
        <section class="space-y-4">
          <Components.section_header
            title="Routing Rules"
            description="Rules determine which agent owns or watches incoming email. Evaluated by priority (lower = first)."
          >
            <:action>
              <.button
                variant="outline"
                size="sm"
                phx-click={Fluxon.open_dialog("add-rule-sheet")}
              >
                <.icon name="hero-plus" class="size-3.5" /> Add rule
              </.button>
            </:action>
          </Components.section_header>

          <%= if @rules == [] do %>
            <div class="rounded-lg border border-base">
              <Components.empty_state
                icon="hero-funnel"
                title="No routing rules"
                description="Add rules to automatically route incoming email to the right agent based on address, domain, or subject."
              >
                <:action>
                  <.button
                    variant="solid"
                    size="sm"
                    phx-click={Fluxon.open_dialog("add-rule-sheet")}
                  >
                    <.icon name="hero-plus" class="size-3.5" /> Add rule
                  </.button>
                </:action>
              </Components.empty_state>
            </div>
          <% else %>
            <div class="space-y-2">
              <Components.rule_card
                :for={rule <- @rules}
                rule={rule}
                agents={@agents}
              />
            </div>
          <% end %>
        </section>

        <%!-- Address Bindings Section --%>
        <section class="space-y-4">
          <Components.section_header
            title="Address Bindings"
            description="Exact address-to-agent mappings. These are evaluated before routing rules."
          >
            <:action>
              <.button
                variant="outline"
                size="sm"
                phx-click={Fluxon.open_dialog("add-binding-sheet")}
              >
                <.icon name="hero-plus" class="size-3.5" /> Add binding
              </.button>
            </:action>
          </Components.section_header>

          <%= if @bindings == [] do %>
            <div class="rounded-lg border border-base">
              <Components.empty_state
                icon="hero-at-symbol"
                title="No address bindings"
                description="Map specific email addresses directly to agents for deterministic routing."
              >
                <:action>
                  <.button
                    variant="solid"
                    size="sm"
                    phx-click={Fluxon.open_dialog("add-binding-sheet")}
                  >
                    <.icon name="hero-plus" class="size-3.5" /> Add binding
                  </.button>
                </:action>
              </Components.empty_state>
            </div>
          <% else %>
            <div class="rounded-lg border border-base overflow-hidden">
              <.table id="bindings-table">
                <.table_head>
                  <:col>Address</:col>
                  <:col>Owner</:col>
                  <:col>Status</:col>
                  <:col></:col>
                </.table_head>
                <.table_body>
                  <.table_row :for={binding <- @bindings}>
                    <:cell>
                      <span class="font-medium text-foreground">{binding.address}</span>
                    </:cell>
                    <:cell>{Helpers.binding_owner_name(binding, @agents)}</:cell>
                    <:cell>
                      <.badge size="xs" variant="soft" color="success">{binding.status}</.badge>
                    </:cell>
                    <:cell>
                      <.button
                        variant="ghost"
                        size="xs"
                        phx-click="clear_binding"
                        phx-value-endpoint_id={binding.id}
                        data-confirm="Remove this address binding?"
                      >
                        <.icon name="hero-x-mark" class="size-3.5" />
                      </.button>
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>
          <% end %>
        </section>
      </div>

      <%!-- ═══════════════════════════════════════ --%>
      <%!-- Slide-over sheets for creation forms    --%>
      <%!-- ═══════════════════════════════════════ --%>

      <%!-- Add Connector Sheet --%>
      <.sheet id="add-connector-sheet" placement="right" class="w-full max-w-md">
        <div class="p-4 space-y-4">
          <div>
            <h2 class="text-lg font-semibold text-foreground">Create Connector</h2>
            <p class="text-sm text-foreground-softer mt-1">
              Set up a new inbound email connector to receive webhooks from your email provider.
            </p>
          </div>

          <.form
            for={to_form(@connector_form, as: :connector)}
            phx-submit="create_connector"
            class="space-y-3"
          >
            <.input
              name="connector[name]"
              value={@connector_form["name"]}
              label="Connector name"
              placeholder="e.g. Support Inbox"
              required
            />
            <.input
              name="connector[default_endpoint_address]"
              value={@connector_form["default_endpoint_address"]}
              label="Default endpoint address"
              placeholder="support@yourcompany.com"
            />

            <div class="space-y-1.5">
              <.label for="connector_default_agent_id">Default owner agent</.label>
              <p class="text-xs text-foreground-softer">
                The agent assigned to emails when no routing rule matches.
              </p>
              <select
                id="connector_default_agent_id"
                name="connector[default_agent_id]"
                class="select w-full"
              >
                <option
                  :for={{label, value} <- Helpers.agent_options(@agents)}
                  value={value}
                  selected={to_string(@connector_form["default_agent_id"] || "") == to_string(value)}
                >
                  {label}
                </option>
              </select>
            </div>

            <.input
              name="connector[signing_secret]"
              type="password"
              value={@connector_form["signing_secret"]}
              label="Signing secret"
              placeholder="whsec_..."
              required
            />
            <p class="text-xs text-foreground-softer -mt-2">
              The webhook signing secret from your email provider (Resend).
            </p>

            <div class="pt-2">
              <.button type="submit" variant="solid" class="w-full">
                Create connector
              </.button>
            </div>
          </.form>
        </div>
      </.sheet>

      <%!-- Add Rule Sheet --%>
      <.sheet id="add-rule-sheet" placement="right" class="w-full max-w-md">
        <div class="p-4 space-y-4">
          <div>
            <h2 class="text-lg font-semibold text-foreground">Add Routing Rule</h2>
            <p class="text-sm text-foreground-softer mt-1">
              Define conditions to route incoming emails to a specific agent.
            </p>
          </div>

          <.form
            for={to_form(@rule_form, as: :rule)}
            phx-submit="create_rule"
            class="space-y-3"
          >
            <.input
              name="rule[name]"
              value={@rule_form["name"]}
              label="Rule name"
              placeholder="e.g. Support routing"
              required
            />

            <div class="space-y-1.5">
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

            <div class="grid grid-cols-2 gap-3">
              <.input
                name="rule[priority]"
                type="number"
                value={@rule_form["priority"]}
                label="Priority"
              />
              <div class="space-y-1.5">
                <.label for="rule_action">Action</.label>
                <select id="rule_action" name="rule[action]" class="select w-full">
                  <option value="owner" selected={@rule_form["action"] == "owner"}>Owner</option>
                  <option value="watcher" selected={@rule_form["action"] == "watcher"}>Watcher</option>
                  <option value="silent" selected={@rule_form["action"] == "silent"}>Silent</option>
                </select>
              </div>
            </div>

            <div class="border-t border-base pt-3 space-y-3">
              <h3 class="text-sm font-medium text-foreground">Match conditions</h3>

              <.input
                name="rule[to_addresses]"
                value={@rule_form["to_addresses"]}
                label="To addresses"
                placeholder="support@co.com, help@co.com"
              />
              <p class="text-xs text-foreground-softer -mt-2">Comma-separated email addresses.</p>

              <.input
                name="rule[to_domains]"
                value={@rule_form["to_domains"]}
                label="To domains"
                placeholder="support.co.com, help.co.com"
              />
              <p class="text-xs text-foreground-softer -mt-2">Comma-separated domain names.</p>

              <.input
                name="rule[subject_contains]"
                value={@rule_form["subject_contains"]}
                label="Subject contains"
                placeholder="e.g. urgent"
              />
            </div>

            <div class="pt-2">
              <.button type="submit" variant="solid" class="w-full">
                Add rule
              </.button>
            </div>
          </.form>
        </div>
      </.sheet>

      <%!-- Add Binding Sheet --%>
      <.sheet id="add-binding-sheet" placement="right" class="w-full max-w-sm">
        <div class="p-4 space-y-4">
          <div>
            <h2 class="text-lg font-semibold text-foreground">Add Address Binding</h2>
            <p class="text-sm text-foreground-softer mt-1">
              Map an email address directly to an agent. Bindings take priority over routing rules.
            </p>
          </div>

          <.form
            for={to_form(@binding_form, as: :binding)}
            phx-submit="create_binding"
            class="space-y-3"
          >
            <.input
              name="binding[address]"
              value={@binding_form["address"]}
              label="Email address"
              placeholder="support@yourcompany.com"
              required
            />

            <div class="space-y-1.5">
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

            <div class="pt-2">
              <.button type="submit" variant="solid" class="w-full">
                Save binding
              </.button>
            </div>
          </.form>
        </div>
      </.sheet>
    </Layouts.app>
    """
  end

  # ──────────────────────────────────────────────
  # Event handlers (extracted from index.ex)
  # ──────────────────────────────────────────────

  @impl true
  def handle_event("create_connector", %{"connector" => params}, socket) do
    attrs = %{
      name: Map.get(params, "name"),
      provider: "resend",
      default_endpoint_address: blank_to_nil(Map.get(params, "default_endpoint_address")),
      default_agent_id: blank_to_nil(Map.get(params, "default_agent_id")),
      signing_secret: blank_to_nil(Map.get(params, "signing_secret")),
      metadata: %{"created_from" => "inbound_email_live"}
    }

    case Inbound.create_connector(socket.assigns.tenant_id, attrs) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inbound connector created.")
         |> assign(:connector_form, connector_form_defaults())
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_changeset_errors(changeset))
         |> assign(:connector_form, Map.merge(connector_form_defaults(), params))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create connector: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_connector", %{"id" => id}, socket) do
    connector = Inbound.get_connector!(socket.assigns.tenant_id, id)

    case Inbound.delete_connector(connector) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Connector deleted.")
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete connector.")}
    end
  end

  @impl true
  def handle_event(
        "update_connector_secret",
        %{"connector_id" => id, "signing_secret" => secret},
        socket
      ) do
    connector = Inbound.get_connector!(socket.assigns.tenant_id, id)

    case Inbound.update_connector(connector, %{signing_secret: blank_to_nil(secret)}) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Signing secret updated.")
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to update signing secret: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("create_rule", %{"rule" => params}, socket) do
    attrs = %{
      "name" => Map.get(params, "name"),
      "agent_id" => Map.get(params, "agent_id"),
      "priority" => parse_integer(Map.get(params, "priority"), 100),
      "action" => Map.get(params, "action", "owner"),
      "predicates" => build_predicates(params)
    }

    case Inbound.create_rule(socket.assigns.tenant_id, attrs) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inbound rule added.")
         |> assign(:rule_form, rule_form_defaults())
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_changeset_errors(changeset))
         |> assign(:rule_form, Map.merge(rule_form_defaults(), params))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create rule: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_rule", %{"id" => id}, socket) do
    rule = Inbound.get_rule!(socket.assigns.tenant_id, id)

    case Inbound.delete_rule(rule) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rule deleted.")
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete rule.")}
    end
  end

  @impl true
  def handle_event("create_binding", %{"binding" => params}, socket) do
    address = blank_to_nil(Map.get(params, "address"))
    owner_agent_id = blank_to_nil(Map.get(params, "owner_agent_id"))

    if is_nil(address) do
      {:noreply, put_flash(socket, :error, "Binding address is required.")}
    else
      case Inbound.upsert_address_binding(socket.assigns.tenant_id, address, owner_agent_id) do
        {:ok, _endpoint} ->
          {:noreply,
           socket
           |> put_flash(:info, "Address binding saved.")
           |> assign(:binding_form, binding_form_defaults())
           |> load_data()}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, format_changeset_errors(changeset))
           |> assign(:binding_form, Map.merge(binding_form_defaults(), params))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to save binding: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_event("clear_binding", %{"endpoint_id" => endpoint_id}, socket) do
    endpoint = Channels.get_endpoint!(socket.assigns.tenant_id, endpoint_id)

    case Inbound.clear_address_binding(endpoint) do
      {:ok, _endpoint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Address binding cleared.")
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to clear binding: #{inspect(reason)}")}
    end
  end

  # ──────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id

    socket
    |> assign(:connectors, Inbound.list_connectors(tenant_id))
    |> assign(:bindings, Inbound.list_address_bindings(tenant_id))
    |> assign(:rules, Inbound.list_rules(tenant_id))
  end

  defp connector_form_defaults do
    %{
      "name" => "",
      "default_endpoint_address" => "",
      "default_agent_id" => "",
      "signing_secret" => ""
    }
  end

  defp rule_form_defaults do
    %{
      "name" => "",
      "agent_id" => "",
      "priority" => "100",
      "action" => "owner",
      "to_addresses" => "",
      "to_domains" => "",
      "subject_contains" => ""
    }
  end

  defp binding_form_defaults do
    %{
      "address" => "",
      "owner_agent_id" => ""
    }
  end

  defp build_predicates(params) do
    predicates = %{}

    predicates =
      put_if_present(predicates, "to_addresses", split_csv(Map.get(params, "to_addresses")))

    predicates =
      put_if_present(predicates, "to_domains", split_csv(Map.get(params, "to_domains")))

    put_if_present(predicates, "subject_contains", Map.get(params, "subject_contains"))
  end

  defp split_csv(nil), do: []

  defp split_csv(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_csv(_value), do: []

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, _key, []), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) do
    case Integer.parse(to_string(value)) do
      {number, ""} -> number
      _ -> default
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message -> "#{field} #{message}" end)
    end)
    |> Enum.join(", ")
  end
end
