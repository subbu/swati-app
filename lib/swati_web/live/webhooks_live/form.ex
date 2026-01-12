defmodule SwatiWeb.WebhooksLive.Form do
  use SwatiWeb, :live_view

  alias Swati.Webhooks
  alias Swati.Webhooks.Tag
  alias Swati.Webhooks.Webhook
  alias SwatiWeb.WebhooksLive.FormComponents
  alias SwatiWeb.WebhooksLive.FormHelpers, as: Helpers

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">{@page_title}</h1>
            <p class="text-sm text-base-content/70">
              Create easy HTTP tools for non-technical teammates.
            </p>
          </div>
          <.button navigate={~p"/agent-data"} variant="ghost">Back</.button>
        </div>

        <.form for={@form} id="webhook-form" phx-change="validate" phx-submit="save">
          <input type="hidden" name="webhook[inputs_present]" value="true" />
          <input type="hidden" name="webhook[headers_present]" value="true" />

          <div class="grid gap-6">
            <FormComponents.basics_section
              form={@form}
              method_options={@method_options}
              status_options={@status_options}
            />
            <FormComponents.tool_section form={@form} tool_name_locked={@tool_name_locked} />
            <FormComponents.tags_section tags={@tags} selected_tag_ids={@selected_tag_ids} />
            <FormComponents.inputs_section
              inputs={@inputs}
              input_type_options={@input_type_options}
              payload_preview={@payload_preview}
            />
            <FormComponents.auth_section
              form={@form}
              auth_type_options={@auth_type_options}
              auth_token={@auth_token}
              header_entries={@header_entries}
            />
          </div>

          <div class="flex justify-end">
            <.button type="submit">Save webhook</.button>
          </div>
        </.form>

        <FormComponents.tag_modal
          tag_form={@tag_form}
          tag_modal_open={@tag_modal_open}
          tag_palette_options={@tag_palette_options}
        />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    palette_options = Webhooks.tag_palette_options()
    default_color = palette_options |> List.first() |> Map.get(:value)

    {:ok,
     socket
     |> assign(:method_options, method_options())
     |> assign(:auth_type_options, auth_type_options())
     |> assign(:status_options, status_options())
     |> assign(:input_type_options, Helpers.input_type_options())
     |> assign(:tool_name_locked, false)
     |> assign(:tags, Webhooks.list_tags(tenant.id))
     |> assign(:selected_tag_ids, [])
     |> assign(:tag_palette_options, palette_options)
     |> assign(:default_tag_color, default_color)
     |> assign(:tag_modal_open, false)
     |> assign(:tag_form, tag_form(%Tag{color: default_color}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        webhook = %Webhook{}

        {:noreply,
         socket
         |> assign(:page_title, "New webhook")
         |> assign_webhook(webhook, %{})}

      :edit ->
        webhook = Webhooks.get_webhook!(socket.assigns.current_scope.tenant.id, params["id"])
        locked = Webhooks.attached?(webhook.id)

        {:noreply,
         socket
         |> assign(:page_title, "Edit webhook")
         |> assign(:tool_name_locked, locked)
         |> assign_webhook(webhook, %{})}
    end
  end

  @impl true
  def handle_event("validate", %{"webhook" => params}, socket) do
    changeset = build_changeset(socket.assigns.webhook, params)

    {:noreply, assign_webhook(socket, socket.assigns.webhook, params, changeset)}
  end

  @impl true
  def handle_event("open-tag-modal", _params, socket) do
    {:noreply, assign(socket, :tag_modal_open, true)}
  end

  @impl true
  def handle_event("close-tag-modal", _params, socket) do
    {:noreply, assign(socket, :tag_modal_open, false)}
  end

  @impl true
  def handle_event("create-tag", %{"tag" => params}, socket) do
    case Webhooks.create_tag(
           socket.assigns.current_scope.tenant.id,
           params,
           socket.assigns.current_scope.user
         ) do
      {:ok, tag} ->
        selected =
          socket.assigns.selected_tag_ids
          |> Enum.concat([to_string(tag.id)])
          |> Enum.uniq()

        {:noreply,
         socket
         |> assign(:tags, Webhooks.list_tags(socket.assigns.current_scope.tenant.id))
         |> assign(:selected_tag_ids, selected)
         |> assign(:tag_modal_open, false)
         |> assign(:tag_form, tag_form(%Tag{color: socket.assigns.default_tag_color}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :tag_form, to_form(changeset, as: :tag))}
    end
  end

  @impl true
  def handle_event("add_input", _params, socket) do
    inputs = socket.assigns.inputs ++ [Helpers.empty_input()]

    {:noreply,
     socket
     |> assign(:inputs, inputs)
     |> assign(:payload_preview, Helpers.payload_preview(inputs))}
  end

  @impl true
  def handle_event("remove_input", %{"index" => index}, socket) do
    inputs = Helpers.remove_at(socket.assigns.inputs, index)

    {:noreply,
     socket
     |> assign(:inputs, inputs)
     |> assign(:payload_preview, Helpers.payload_preview(inputs))}
  end

  @impl true
  def handle_event("add_header", _params, socket) do
    header_entries = socket.assigns.header_entries ++ [Helpers.empty_header()]

    {:noreply, assign(socket, :header_entries, header_entries)}
  end

  @impl true
  def handle_event("remove_header", %{"index" => index}, socket) do
    header_entries = Helpers.remove_at(socket.assigns.header_entries, index)

    {:noreply, assign(socket, :header_entries, header_entries)}
  end

  @impl true
  def handle_event("save", %{"webhook" => params}, socket) do
    case socket.assigns.live_action do
      :new ->
        case Webhooks.create_webhook(
               socket.assigns.current_scope.tenant.id,
               params,
               socket.assigns.current_scope.user
             ) do
          {:ok, _webhook} ->
            {:noreply,
             socket
             |> put_flash(:info, "Webhook created.")
             |> push_navigate(to: ~p"/agent-data")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_webhook(socket, socket.assigns.webhook, params, changeset)}

          {:error, {field, message}} ->
            {:noreply, handle_parse_error(socket, params, field, message)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, to_string(reason))}
        end

      :edit ->
        case Webhooks.update_webhook(
               socket.assigns.webhook,
               params,
               socket.assigns.current_scope.user
             ) do
          {:ok, webhook} ->
            {:noreply,
             socket
             |> put_flash(:info, "Webhook updated.")
             |> assign_webhook(webhook, %{})}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign_webhook(socket, socket.assigns.webhook, params, changeset)}

          {:error, {field, message}} ->
            {:noreply, handle_parse_error(socket, params, field, message)}

          {:error, "tool_name_locked"} ->
            {:noreply,
             socket
             |> put_flash(:error, "Tool name is locked after attaching to an agent.")
             |> assign_webhook(socket.assigns.webhook, params)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, to_string(reason))}
        end
    end
  end

  defp handle_parse_error(socket, params, field, message) do
    changeset =
      socket.assigns.webhook
      |> Webhook.changeset(params)
      |> Ecto.Changeset.add_error(field, message)

    socket
    |> put_flash(:error, message)
    |> assign_webhook(socket.assigns.webhook, params, changeset)
  end

  defp assign_webhook(socket, webhook, params, changeset \\ nil) do
    changeset = changeset || build_changeset(webhook, params)
    inputs = inputs_from_params(params, webhook)
    header_entries = header_entries_from_params(params, webhook)
    tag_ids = tag_ids_from_params(params, webhook)

    socket
    |> assign(:webhook, webhook)
    |> assign(:form, to_form(changeset, as: :webhook))
    |> assign(:inputs, inputs)
    |> assign(:header_entries, header_entries)
    |> assign(:selected_tag_ids, tag_ids)
    |> assign(:payload_preview, Helpers.payload_preview(inputs))
    |> assign(:auth_token, Map.get(params, "auth_token", ""))
  end

  defp tag_ids_from_params(params, webhook) do
    case Map.fetch(params, "tag_ids") do
      {:ok, tag_ids} -> Webhooks.normalize_tag_ids(tag_ids)
      :error -> tag_ids_from_webhook(webhook)
    end
  end

  defp tag_ids_from_webhook(%Webhook{tags: tags}) when is_list(tags) do
    Enum.map(tags, &to_string(&1.id))
  end

  defp tag_ids_from_webhook(_webhook), do: []

  defp tag_form(tag) do
    tag
    |> Ecto.Changeset.change()
    |> to_form(as: :tag)
  end

  defp build_changeset(webhook, params) do
    case Webhooks.normalize_attrs(params) do
      {:ok, attrs} ->
        Webhook.changeset(webhook, attrs)

      {:error, {field, message}} ->
        webhook
        |> Webhook.changeset(params)
        |> Ecto.Changeset.add_error(field, message)
    end
  end

  defp inputs_from_params(params, webhook) do
    if Helpers.present?(Map.get(params, "inputs_present")) do
      params
      |> Map.get("inputs")
      |> Helpers.normalize_list()
      |> Enum.map(&normalize_input_params/1)
    else
      inputs_from_webhook(webhook)
    end
  end

  defp inputs_from_webhook(%Webhook{input_schema: schema, sample_payload: payload}) do
    required = Helpers.schema_required(schema)

    schema
    |> Helpers.schema_properties()
    |> Enum.map(fn {name, meta} ->
      %{
        "name" => name,
        "type" => Helpers.normalize_input_type(Map.get(meta, "type")),
        "required" => name in required,
        "description" => Map.get(meta, "description", ""),
        "example" => Helpers.example_for(payload, name)
      }
    end)
  end

  defp inputs_from_webhook(_webhook), do: []

  defp header_entries_from_params(params, webhook) do
    if Helpers.present?(Map.get(params, "headers_present")) do
      params
      |> Map.get("header_entries")
      |> Helpers.normalize_list()
      |> Enum.map(&normalize_header_params/1)
    else
      header_entries_from_webhook(webhook)
    end
  end

  defp header_entries_from_webhook(%Webhook{headers: headers}) when is_map(headers) do
    headers
    |> Enum.map(fn {key, value} ->
      %{"key" => to_string(key), "value" => to_string(value)}
    end)
    |> Enum.sort_by(& &1["key"])
  end

  defp header_entries_from_webhook(_webhook), do: []

  defp normalize_input_params(entry) when is_map(entry) do
    %{
      "name" => Helpers.entry_value(entry, "name") |> to_string() |> String.trim(),
      "type" => Helpers.normalize_input_type(Helpers.entry_value(entry, "type")),
      "required" => Helpers.truthy?(Helpers.entry_value(entry, "required")),
      "description" => Helpers.entry_value(entry, "description") |> to_string() |> String.trim(),
      "example" => Helpers.entry_value(entry, "example") |> to_string() |> String.trim()
    }
  end

  defp normalize_input_params(_entry), do: Helpers.empty_input()

  defp normalize_header_params(entry) when is_map(entry) do
    %{
      "key" => Helpers.entry_value(entry, "key") |> to_string() |> String.trim(),
      "value" => Helpers.entry_value(entry, "value") |> to_string() |> String.trim()
    }
  end

  defp normalize_header_params(_entry), do: Helpers.empty_header()

  defp method_options do
    [
      {"POST", "post"},
      {"GET", "get"},
      {"PUT", "put"},
      {"PATCH", "patch"},
      {"DELETE", "delete"}
    ]
  end

  defp auth_type_options do
    [{"None", "none"}, {"Bearer", "bearer"}]
  end

  defp status_options do
    [{"Active", "active"}, {"Disabled", "disabled"}]
  end
end
