defmodule SwatiWeb.WhatsAppTemplatesLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Channels
  alias Swati.Repo

  @manager_url "https://business.facebook.com/latest/whatsapp_manager/"

  @impl true
  def mount(_params, _session, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    connections = list_whatsapp_connections(tenant_id)
    selected_connection = List.first(connections)

    {templates, templates_error} =
      fetch_templates(tenant_id, selected_connection && selected_connection.id)

    selected_template = pick_default_template(templates)
    evidence = fetch_evidence(tenant_id, selected_connection && selected_connection.id)

    {:ok,
     socket
     |> assign(:connections, connections)
     |> assign(:selected_connection_id, selected_connection && selected_connection.id)
     |> assign(:selected_connection, selected_connection)
     |> assign(:templates, templates)
     |> assign(:templates_error, templates_error)
     |> assign(:template_filter, "all")
     |> assign(:selected_template_id, template_id(selected_template))
     |> assign(:selected_template, selected_template)
     |> assign(:selected_template_vars, template_vars(selected_template))
     |> assign(:manager_url, @manager_url)
     |> assign(:template_create_sheet_open, false)
     |> assign(:creating_template, false)
     |> assign(:create_template_form, to_form(default_create_template_form(), as: :template))
     |> assign(:sending_template, false)
     |> assign(:send_template_form, to_form(default_send_form(selected_template), as: :send))
     |> assign(:evidence_messages, evidence)}
  end

  @impl true
  def handle_event("select_connection", %{"connection_id" => connection_id}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    selected_connection = find_connection(socket.assigns.connections, connection_id)

    if selected_connection do
      {templates, templates_error} = fetch_templates(tenant_id, selected_connection.id)
      selected_template = pick_default_template(templates)
      evidence = fetch_evidence(tenant_id, selected_connection.id)

      {:noreply,
       socket
       |> assign(:selected_connection_id, selected_connection.id)
       |> assign(:selected_connection, selected_connection)
       |> assign(:templates, templates)
       |> assign(:templates_error, templates_error)
       |> assign(:selected_template_id, template_id(selected_template))
       |> assign(:selected_template, selected_template)
       |> assign(:selected_template_vars, template_vars(selected_template))
       |> assign(:send_template_form, to_form(default_send_form(selected_template), as: :send))
       |> assign(:evidence_messages, evidence)}
    else
      {:noreply, put_flash(socket, :error, "Connection not found.")}
    end
  end

  def handle_event("set_template_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :template_filter, normalize_filter(filter))}
  end

  def handle_event("refresh_templates", _params, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    connection_id = socket.assigns.selected_connection_id
    {templates, templates_error} = fetch_templates(tenant_id, connection_id)

    selected_template =
      find_template_by_id(templates, socket.assigns.selected_template_id) ||
        pick_default_template(templates)

    {:noreply,
     socket
     |> assign(:templates, templates)
     |> assign(:templates_error, templates_error)
     |> assign(:selected_template_id, template_id(selected_template))
     |> assign(:selected_template, selected_template)
     |> assign(:selected_template_vars, template_vars(selected_template))
     |> assign(
       :send_template_form,
       to_form(default_send_form(selected_template, socket.assigns.send_template_form.params),
         as: :send
       )
     )}
  end

  def handle_event("open_create_template_sheet", _params, socket) do
    {:noreply, assign(socket, :template_create_sheet_open, true)}
  end

  def handle_event("close_create_template_sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:template_create_sheet_open, false)
     |> assign(:creating_template, false)}
  end

  def handle_event("validate_create_template", %{"template" => params}, socket) do
    {:noreply, assign(socket, :create_template_form, to_form(params, as: :template))}
  end

  def handle_event("create_template", %{"template" => params}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    connection_id = socket.assigns.selected_connection_id

    if is_nil(connection_id) do
      {:noreply, put_flash(socket, :error, "Connect a WhatsApp number first.")}
    else
      case Channels.create_whatsapp_template(tenant_id, connection_id, params) do
        {:ok, response} ->
          {templates, templates_error} = fetch_templates(tenant_id, connection_id)
          selected_template = pick_template_after_create(templates, response)

          {:noreply,
           socket
           |> clear_flash(:error)
           |> put_flash(:info, "Template created. Review status is now visible below.")
           |> assign(:template_create_sheet_open, false)
           |> assign(:creating_template, false)
           |> assign(
             :create_template_form,
             to_form(default_create_template_form(), as: :template)
           )
           |> assign(:templates, templates)
           |> assign(:templates_error, templates_error)
           |> assign(:selected_template_id, template_id(selected_template))
           |> assign(:selected_template, selected_template)
           |> assign(:selected_template_vars, template_vars(selected_template))
           |> assign(
             :send_template_form,
             to_form(default_send_form(selected_template), as: :send)
           )}

        {:error, :template_name_invalid} ->
          {:noreply,
           put_flash(socket, :error, "Template name invalid. Use letters, numbers, underscore.")}

        {:error, :template_category_invalid} ->
          {:noreply,
           put_flash(
             socket,
             :error,
             "Template category must be UTILITY, MARKETING, or AUTHENTICATION."
           )}

        {:error, :template_language_invalid} ->
          {:noreply, put_flash(socket, :error, "Template language is required (example: en_US).")}

        {:error, {:http_error, _status, body}} ->
          {:noreply,
           put_flash(socket, :error, "Meta rejected template create: #{format_http_body(body)}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Template create failed: #{inspect(reason)}")}
      end
    end
  end

  def handle_event("select_template", %{"id" => id}, socket) do
    selected_template = find_template_by_id(socket.assigns.templates, id)

    if selected_template do
      {:noreply,
       socket
       |> assign(:selected_template_id, template_id(selected_template))
       |> assign(:selected_template, selected_template)
       |> assign(:selected_template_vars, template_vars(selected_template))
       |> assign(
         :send_template_form,
         to_form(
           default_send_form(selected_template, socket.assigns.send_template_form.params),
           as: :send
         )
       )}
    else
      {:noreply, put_flash(socket, :error, "Template not found.")}
    end
  end

  def handle_event("validate_send_template", %{"send" => params}, socket) do
    selected_template = socket.assigns.selected_template

    {:noreply,
     socket
     |> assign(:selected_template_vars, template_vars(selected_template))
     |> assign(
       :send_template_form,
       to_form(default_send_form(selected_template, params), as: :send)
     )}
  end

  def handle_event("send_template", %{"send" => params}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    connection_id = socket.assigns.selected_connection_id
    selected_template = socket.assigns.selected_template

    cond do
      is_nil(connection_id) ->
        {:noreply, put_flash(socket, :error, "Select a connected WhatsApp number first.")}

      is_nil(selected_template) ->
        {:noreply, put_flash(socket, :error, "Choose a template first.")}

      not template_approved?(selected_template) ->
        {:noreply,
         put_flash(socket, :error, "Template is not approved yet. Choose an approved template.")}

      true ->
        with {:ok, template_payload} <-
               build_template_payload_for_send(selected_template, params),
             {:ok, _result} <-
               Channels.send_whatsapp_template(tenant_id, connection_id, %{
                 "to" => Map.get(params, "to"),
                 "template" => template_payload
               }) do
          evidence = fetch_evidence(tenant_id, connection_id)

          {:noreply,
           socket
           |> clear_flash(:error)
           |> put_flash(
             :info,
             "Template message sent. Delivery events will stream in via webhook."
           )
           |> assign(:evidence_messages, evidence)
           |> assign(
             :send_template_form,
             to_form(default_send_form(selected_template), as: :send)
           )}
        else
          {:error, :message_payload_invalid} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Missing required fields. Fill recipient and all required template variables."
             )}

          {:error, {:http_error, _status, body}} ->
            {:noreply, put_flash(socket, :error, "Meta send failed: #{format_http_body(body)}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Template send failed: #{inspect(reason)}")}
        end
    end
  end

  @impl true
  def render(assigns) do
    filtered_templates = filtered_templates(assigns.templates, assigns.template_filter)
    checklist = reviewer_checklist(assigns)

    assigns =
      assigns
      |> assign(:filtered_templates, filtered_templates)
      |> assign(:checklist, checklist)

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="wa-template-flow" class="space-y-8">
        <header class="space-y-2">
          <div class="flex flex-wrap items-center gap-2 text-xs text-foreground-soft">
            <.link navigate={~p"/surfaces"} class="hover:text-foreground">Surfaces</.link>
            <span>/</span>
            <span class="text-foreground">WhatsApp Templates</span>
          </div>
          <h1 class="text-2xl font-semibold tracking-tight text-foreground">
            WhatsApp Template Lifecycle
          </h1>
          <p class="text-sm text-foreground-soft">
            Create or select templates, prove approval status, send to a test number, and capture delivery evidence.
          </p>
        </header>

        <section class="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <div
            :for={item <- @checklist}
            class="rounded-xl border border-base-300 bg-base-100 p-4 space-y-2"
          >
            <div class="flex items-center justify-between gap-2">
              <p class="text-xs uppercase tracking-wide text-foreground-soft">{item.step}</p>
              <.badge size="xs" variant="soft" color={item.color}>{item.state}</.badge>
            </div>
            <p class="text-sm text-foreground">{item.detail}</p>
          </div>
        </section>

        <section class="rounded-xl border border-base-300 bg-base-100 p-5 space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="text-sm font-semibold text-foreground">1. Connection and Management</h2>
            <a href={@manager_url} target="_blank" rel="noreferrer" class="inline-flex">
              <.button size="xs" variant="dashed">Open WhatsApp Manager</.button>
            </a>
          </div>

          <div class="grid gap-4 md:grid-cols-2">
            <.select
              id="wa-connection-select"
              name="connection_id"
              label="Connected WhatsApp number"
              value={@selected_connection_id}
              options={connection_options(@connections)}
              phx-change="select_connection"
            />

            <div class="rounded-lg border border-base-300 bg-base-200/30 p-3 text-xs space-y-1">
              <div class="flex justify-between gap-2">
                <span class="text-foreground-soft">WABA ID</span>
                <span class="font-mono text-foreground">
                  {connection_meta(@selected_connection, "waba_id") || "—"}
                </span>
              </div>
              <div class="flex justify-between gap-2">
                <span class="text-foreground-soft">Phone Number ID</span>
                <span class="font-mono text-foreground">
                  {connection_meta(@selected_connection, "phone_number_id") || "—"}
                </span>
              </div>
              <div class="flex justify-between gap-2">
                <span class="text-foreground-soft">Verified Name</span>
                <span class="text-foreground">
                  {connection_meta(@selected_connection, "verified_name") || "—"}
                </span>
              </div>
            </div>
          </div>

          <%= if @connections == [] do %>
            <div class="rounded-lg border border-dashed border-base-300 bg-base-200/40 p-4 text-sm text-foreground-soft">
              No WhatsApp connections yet. Connect WhatsApp from Surfaces first.
            </div>
          <% end %>
        </section>

        <section class="rounded-xl border border-base-300 bg-base-100 p-5 space-y-4">
          <div class="flex flex-wrap items-center justify-between gap-3">
            <h2 class="text-sm font-semibold text-foreground">
              2. Template Library and Approval Status
            </h2>
            <div class="flex items-center gap-2">
              <.button
                size="xs"
                variant="ghost"
                phx-click="set_template_filter"
                phx-value-filter="all"
              >
                All
              </.button>
              <.button
                size="xs"
                variant="ghost"
                phx-click="set_template_filter"
                phx-value-filter="approved"
              >
                Approved
              </.button>
              <.button size="xs" variant="ghost" phx-click="refresh_templates">Refresh</.button>
              <.button size="xs" variant="solid" phx-click="open_create_template_sheet">
                Create template
              </.button>
            </div>
          </div>

          <%= if @templates_error do %>
            <div class="rounded-lg border border-warning/40 bg-warning/10 px-3 py-2 text-xs text-warning">
              Failed to load templates: {inspect(@templates_error)}
            </div>
          <% end %>

          <div class="overflow-x-auto">
            <.table id="wa-template-table">
              <.table_head>
                <:col>Name</:col>
                <:col>Language</:col>
                <:col>Category</:col>
                <:col>Status</:col>
                <:col>Updated</:col>
                <:col class="text-right">Action</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={template <- @filtered_templates}>
                  <:cell class="font-medium text-foreground">{template["name"]}</:cell>
                  <:cell>{template["language"] || "—"}</:cell>
                  <:cell>{template["category"] || "—"}</:cell>
                  <:cell>
                    <.badge size="xs" variant="soft" color={template_status_color(template["status"])}>
                      {template["status"] || "UNKNOWN"}
                    </.badge>
                  </:cell>
                  <:cell>{template["last_updated_time"] || "—"}</:cell>
                  <:cell class="text-right">
                    <.button
                      size="xs"
                      variant={
                        if template_id(template) == @selected_template_id, do: "solid", else: "ghost"
                      }
                      phx-click="select_template"
                      phx-value-id={template_id(template)}
                    >
                      {if template_id(template) == @selected_template_id, do: "Selected", else: "Use"}
                    </.button>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%= if @filtered_templates == [] do %>
            <p class="text-sm text-foreground-soft">
              No templates found for this filter.
            </p>
          <% end %>
        </section>

        <section class="rounded-xl border border-base-300 bg-base-100 p-5 space-y-4">
          <div class="flex items-center justify-between gap-3">
            <h2 class="text-sm font-semibold text-foreground">3. Send Template to Test Number</h2>
            <.badge
              size="xs"
              variant="soft"
              color={if template_approved?(@selected_template), do: "success", else: "warning"}
            >
              {if template_approved?(@selected_template), do: "Ready", else: "Template not approved"}
            </.badge>
          </div>

          <.form
            for={@send_template_form}
            id="wa-template-send-form"
            phx-change="validate_send_template"
            phx-submit="send_template"
            class="space-y-4"
          >
            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@send_template_form[:to]}
                label="Test recipient (E.164)"
                placeholder="+15555550123"
              />
              <.input
                name="send[selected_template]"
                value={if @selected_template, do: @selected_template["name"], else: ""}
                label="Selected template"
                readonly
              />
            </div>

            <div :if={@selected_template_vars.header != []} class="grid gap-4 md:grid-cols-2">
              <.input
                :for={idx <- @selected_template_vars.header}
                name={"send[header_var_#{idx}]"}
                value={send_param(@send_template_form, "header_var_#{idx}")}
                label={"Header variable {{#{idx}}}"}
                placeholder="Value"
              />
            </div>

            <div :if={@selected_template_vars.body != []} class="grid gap-4 md:grid-cols-2">
              <.input
                :for={idx <- @selected_template_vars.body}
                name={"send[body_var_#{idx}]"}
                value={send_param(@send_template_form, "body_var_#{idx}")}
                label={"Body variable {{#{idx}}}"}
                placeholder="Value"
              />
            </div>

            <p class="text-xs text-foreground-soft">
              Use real test number. Delivery state will appear in the timeline below.
            </p>

            <div class="flex justify-end">
              <.button
                type="submit"
                variant="solid"
                disabled={is_nil(@selected_template) || not template_approved?(@selected_template)}
              >
                Send template
              </.button>
            </div>
          </.form>
        </section>

        <section class="rounded-xl border border-base-300 bg-base-100 p-5 space-y-4">
          <h2 class="text-sm font-semibold text-foreground">4. Delivery Evidence Timeline</h2>

          <div class="overflow-x-auto">
            <.table id="wa-delivery-table">
              <.table_head>
                <:col>Sent at</:col>
                <:col>Template</:col>
                <:col>Recipient</:col>
                <:col>Status</:col>
                <:col>Message ID</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={msg <- @evidence_messages}>
                  <:cell>{format_dt(msg.sent_at || msg.inserted_at)}</:cell>
                  <:cell>{msg.template_name} ({msg.template_language})</:cell>
                  <:cell>{msg.recipient}</:cell>
                  <:cell>
                    <.badge size="xs" variant="soft" color={message_status_color(msg.status)}>
                      {msg.status}
                    </.badge>
                  </:cell>
                  <:cell class="font-mono text-xs">{msg.meta_message_id || "—"}</:cell>
                </.table_row>
              </.table_body>
            </.table>
          </div>

          <%= if @evidence_messages == [] do %>
            <p class="text-sm text-foreground-soft">No template sends yet.</p>
          <% end %>
        </section>
      </div>

      <.sheet
        id="wa-create-template-sheet"
        placement="right"
        class="w-full max-w-xl"
        open={@template_create_sheet_open}
        on_close={JS.push("close_create_template_sheet")}
      >
        <div class="space-y-5">
          <header class="space-y-1">
            <h3 class="text-lg font-semibold text-foreground">Create WhatsApp Template</h3>
            <p class="text-sm text-foreground-soft">
              This records create proof for review. Approval status will show in template table.
            </p>
          </header>

          <.form
            for={@create_template_form}
            id="wa-template-create-form"
            phx-change="validate_create_template"
            phx-submit="create_template"
            class="space-y-4"
          >
            <div class="grid gap-4 md:grid-cols-2">
              <.input
                field={@create_template_form[:name]}
                label="Template name"
                placeholder="order_update"
              />
              <.input
                field={@create_template_form[:language]}
                label="Language"
                placeholder="en_US"
              />
            </div>

            <.select
              field={@create_template_form[:category]}
              label="Category"
              options={[
                {"Utility", "UTILITY"},
                {"Marketing", "MARKETING"},
                {"Authentication", "AUTHENTICATION"}
              ]}
            />

            <.input
              field={@create_template_form[:header_text]}
              label="Header text (optional)"
              placeholder="Order update"
            />
            <.input
              field={@create_template_form[:body_text]}
              label="Body text"
              placeholder="Hi {{1}}, your order {{2}} has shipped."
            />
            <.input
              field={@create_template_form[:footer_text]}
              label="Footer text (optional)"
              placeholder="Reply STOP to opt out"
            />
            <.input
              field={@create_template_form[:body_example_values]}
              label="Body example values (comma-separated)"
              placeholder="Alex, ORD-1001"
            />

            <div class="flex justify-end">
              <.button type="submit" variant="solid">Create template</.button>
            </div>
          </.form>
        </div>
      </.sheet>
    </Layouts.app>
    """
  end

  defp list_whatsapp_connections(tenant_id) do
    Channels.list_connections(tenant_id, %{provider: :whatsapp})
    |> Repo.preload(:endpoint)
  end

  defp fetch_templates(_tenant_id, nil), do: {[], nil}

  defp fetch_templates(tenant_id, connection_id) do
    case Channels.list_whatsapp_templates(tenant_id, connection_id) do
      {:ok, templates} -> {templates, nil}
      {:error, reason} -> {[], reason}
    end
  end

  defp fetch_evidence(_tenant_id, nil), do: []

  defp fetch_evidence(tenant_id, connection_id) do
    Channels.list_whatsapp_template_messages(tenant_id, connection_id, limit: 40)
  end

  defp default_create_template_form do
    %{
      "name" => "",
      "language" => "en_US",
      "category" => "UTILITY",
      "header_text" => "",
      "body_text" => "",
      "footer_text" => "",
      "body_example_values" => ""
    }
  end

  defp default_send_form(template, params \\ %{}) do
    vars = template_vars(template)
    params = params || %{}

    base = %{"to" => Map.get(params, "to", "")}

    base =
      Enum.reduce(vars.header, base, fn idx, acc ->
        key = "header_var_#{idx}"
        Map.put(acc, key, Map.get(params, key, ""))
      end)

    Enum.reduce(vars.body, base, fn idx, acc ->
      key = "body_var_#{idx}"
      Map.put(acc, key, Map.get(params, key, ""))
    end)
  end

  defp build_template_payload_for_send(template, params) do
    vars = template_vars(template)

    with {:ok, _to} <- require_text(Map.get(params, "to")),
         {:ok, header_params} <- build_component_params("header", vars.header, params),
         {:ok, body_params} <- build_component_params("body", vars.body, params) do
      components = []
      components = if header_params == [], do: components, else: components ++ [header_params]
      components = if body_params == [], do: components, else: components ++ [body_params]

      payload = %{
        "name" => template["name"],
        "language" => %{"code" => template["language"] || "en_US"}
      }

      payload = if components == [], do: payload, else: Map.put(payload, "components", components)

      {:ok, payload}
    end
  end

  defp build_component_params(_type, [], _params), do: {:ok, []}

  defp build_component_params(type, indices, params) do
    built =
      Enum.map(indices, fn idx ->
        key = "#{type}_var_#{idx}"
        value = Map.get(params, key)
        {idx, value}
      end)

    if Enum.any?(built, fn {_idx, value} -> not text_present?(value) end) do
      {:error, :message_payload_invalid}
    else
      {:ok,
       %{
         "type" => type,
         "parameters" =>
           Enum.map(built, fn {_idx, value} ->
             %{"type" => "text", "text" => String.trim(to_string(value))}
           end)
       }}
    end
  end

  defp connection_options(connections) do
    Enum.map(connections, fn connection ->
      label =
        (connection.endpoint && connection.endpoint.address) ||
          connection_meta(connection, "display_phone_number") ||
          connection.id

      {label, connection.id}
    end)
  end

  defp connection_meta(nil, _key), do: nil

  defp connection_meta(connection, key) do
    connection
    |> Map.get(:metadata, %{})
    |> Map.get(key)
  end

  defp find_connection(connections, connection_id) do
    Enum.find(connections, fn connection ->
      to_string(connection.id) == to_string(connection_id)
    end)
  end

  defp filtered_templates(templates, "approved") do
    Enum.filter(templates, &template_approved?/1)
  end

  defp filtered_templates(templates, _), do: templates

  defp template_status_color(status) do
    case normalize_status(status) do
      "approved" -> "success"
      "pending" -> "warning"
      "rejected" -> "error"
      "paused" -> "warning"
      _ -> "info"
    end
  end

  defp message_status_color(status) do
    case normalize_status(status) do
      "read" -> "success"
      "delivered" -> "success"
      "sent" -> "info"
      "failed" -> "error"
      _ -> "warning"
    end
  end

  defp normalize_status(status) do
    status
    |> to_string()
    |> String.downcase()
  end

  defp template_approved?(nil), do: false

  defp template_approved?(template) do
    normalize_status(template["status"]) == "approved"
  end

  defp pick_default_template(templates) do
    Enum.find(templates, &template_approved?/1) || List.first(templates)
  end

  defp pick_template_after_create(templates, response) do
    id = Map.get(response, "id")

    find_template_by_id(templates, id) ||
      Enum.find(templates, fn template -> template["name"] == Map.get(response, "name") end) ||
      pick_default_template(templates)
  end

  defp find_template_by_id(_templates, nil), do: nil

  defp find_template_by_id(templates, id) do
    Enum.find(templates, fn template ->
      template_id(template) == to_string(id)
    end)
  end

  defp template_id(template) when is_map(template) do
    Map.get(template, "id") || "#{Map.get(template, "name")}:#{Map.get(template, "language")}"
  end

  defp template_id(_template), do: nil

  defp template_vars(nil), do: %{header: [], body: []}

  defp template_vars(template) do
    components = Map.get(template, "components") || []

    %{
      header: extract_placeholder_indices(components, "HEADER"),
      body: extract_placeholder_indices(components, "BODY")
    }
  end

  defp extract_placeholder_indices(components, type) do
    text =
      components
      |> Enum.find(fn component ->
        normalize_component_type(component["type"]) == String.downcase(type)
      end)
      |> case do
        nil -> nil
        component -> component["text"]
      end

    regex = ~r/\{\{\s*(\d+)\s*\}\}/

    Regex.scan(regex, to_string(text))
    |> Enum.map(fn [_full, idx] -> String.to_integer(idx) end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp normalize_component_type(type) do
    type
    |> to_string()
    |> String.downcase()
  end

  defp reviewer_checklist(assigns) do
    approved_count = Enum.count(assigns.templates, &template_approved?/1)
    sent_messages = length(assigns.evidence_messages)

    delivered =
      Enum.any?(assigns.evidence_messages, fn msg -> msg.status in ["delivered", "read"] end)

    [
      %{
        step: "Step 1",
        state: if(assigns.selected_connection, do: "Connected", else: "Missing"),
        color: if(assigns.selected_connection, do: "success", else: "warning"),
        detail:
          if(assigns.selected_connection,
            do: "WhatsApp connection selected and scoped.",
            else: "Connect WhatsApp in Surfaces."
          )
      },
      %{
        step: "Step 2",
        state: if(approved_count > 0, do: "Approved seen", else: "Waiting approval"),
        color: if(approved_count > 0, do: "success", else: "warning"),
        detail: "#{approved_count} approved templates visible in list."
      },
      %{
        step: "Step 3",
        state: if(sent_messages > 0, do: "Sent", else: "Not sent"),
        color: if(sent_messages > 0, do: "success", else: "info"),
        detail:
          if(sent_messages > 0,
            do: "Template send recorded with message id.",
            else: "Send one template to test number."
          )
      },
      %{
        step: "Step 4",
        state: if(delivered, do: "Delivered", else: "Awaiting receipt"),
        color: if(delivered, do: "success", else: "warning"),
        detail:
          if(delivered,
            do: "Webhook delivery state captured.",
            else: "Wait for webhook statuses (sent/delivered/read)."
          )
      }
    ]
  end

  defp send_param(form, key) do
    params = form.params || %{}
    Map.get(params, key, "")
  end

  defp format_dt(nil), do: "—"

  defp format_dt(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M:%S")
  end

  defp format_http_body(body) when is_map(body) do
    cond do
      is_binary(get_in(body, ["error", "message"])) -> get_in(body, ["error", "message"])
      true -> inspect(body)
    end
  end

  defp format_http_body(body), do: inspect(body)

  defp normalize_filter("approved"), do: "approved"
  defp normalize_filter(_), do: "all"

  defp require_text(value) do
    if text_present?(value) do
      {:ok, String.trim(to_string(value))}
    else
      {:error, :message_payload_invalid}
    end
  end

  defp text_present?(value) do
    value
    |> to_string()
    |> String.trim()
    |> then(&(&1 != ""))
  rescue
    _ -> false
  end
end
