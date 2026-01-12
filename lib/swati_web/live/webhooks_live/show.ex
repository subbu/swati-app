defmodule SwatiWeb.WebhooksLive.Show do
  use SwatiWeb, :live_view

  alias Phoenix.LiveView.JS
  alias Swati.Webhooks

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
          <div class="space-y-2">
            <div class="flex flex-wrap items-center gap-2">
              <h1 class="text-2xl font-semibold">{@webhook.name}</h1>
              <.badge color="info" variant="soft">Webhook</.badge>
              <.badge color={status_color(@webhook.status)} variant="soft">
                {status_label(@webhook.status)}
              </.badge>
            </div>
            <div :if={@webhook.tags != []} class="flex flex-wrap gap-2">
              <span
                :for={tag <- sort_tags(@webhook.tags)}
                class="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold"
                style={tag_style(tag)}
              >
                <span class="h-2 w-2 rounded-full" style={tag_dot_style(tag)}></span>
                {tag.name}
              </span>
            </div>
            <p class="text-sm text-base-content/70">{@webhook.endpoint_url}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <.button id="webhook-test-button" variant="soft" phx-click="test">
              Test webhook
            </.button>
            <.button id="webhook-edit-button" navigate={~p"/webhooks/#{@webhook.id}/edit"}>
              Edit
            </.button>
            <.button
              id="webhook-delete-button"
              variant="ghost"
              phx-click="open_delete"
            >
              Delete
            </.button>
            <.button id="webhook-back-button" navigate={~p"/agent-data"} variant="ghost">
              Back
            </.button>
          </div>
        </div>

        <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Status</p>
            <div class="mt-2 flex items-center gap-2">
              <.badge color={test_status_color(@webhook.last_test_status)} variant="soft">
                {test_status_label(@webhook.last_test_status)}
              </.badge>
              <span class="text-xs text-base-content/60">
                {last_test_label(@webhook.last_tested_at)}
              </span>
            </div>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Method</p>
            <p class="mt-2 text-sm font-medium">{method_label(@webhook.http_method)}</p>
            <p class="text-xs text-base-content/60">HTTP request</p>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Timeout</p>
            <p class="mt-2 text-sm font-medium">{@webhook.timeout_secs}s</p>
            <p class="text-xs text-base-content/60">Tool execution window</p>
          </section>

          <section class="rounded-2xl border border-base-300 bg-base-100 p-4">
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">Auth</p>
            <p class="mt-2 text-sm font-medium">{auth_label(@webhook.auth_type)}</p>
            <p class="text-xs text-base-content/60">{auth_hint(@webhook.auth_type)}</p>
          </section>
        </div>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <div class="space-y-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Tool definition</h2>
              <div class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Tool name
                </p>
                <p class="text-sm font-medium">{@webhook.tool_name}</p>
              </div>
              <div :if={present?(@webhook.description)} class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Description
                </p>
                <p class="text-sm font-medium">{@webhook.description}</p>
              </div>
              <div class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Inputs
                </p>
                <%= if schema_properties(@webhook.input_schema) == [] do %>
                  <p class="text-sm text-base-content/60">No inputs defined.</p>
                <% else %>
                  <div class="divide-y divide-base-300">
                    <div
                      :for={{name, meta} <- schema_properties(@webhook.input_schema)}
                      class="py-2"
                    >
                      <div class="flex items-center justify-between gap-3">
                        <div>
                          <p class="text-sm font-medium">{name}</p>
                          <p class="text-xs text-base-content/60">
                            {schema_description(meta)}
                          </p>
                        </div>
                        <div class="flex items-center gap-2">
                          <.badge color="info" variant="soft">{schema_type(meta)}</.badge>
                          <%= if schema_required?(@webhook.input_schema, name) do %>
                            <.badge color="warning" variant="soft">Required</.badge>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
              <div class="space-y-2">
                <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                  Sample payload
                </p>
                <%= if @payload_text == "" do %>
                  <p class="text-sm text-base-content/60">No sample payload saved.</p>
                <% else %>
                  <pre
                    class="rounded-xl border border-base-300 bg-base-200/40 p-3 text-xs"
                    phx-no-curly-interpolation
                  ><%= @payload_text %></pre>
                <% end %>
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Request headers</h2>
              <div class="rounded-xl border border-base-300 bg-base-200/40 p-4 text-xs space-y-1">
                <%= if header_lines(@webhook) == [] do %>
                  <p class="text-sm text-base-content/60">No custom headers configured.</p>
                <% else %>
                  <pre phx-no-curly-interpolation><%= Enum.join(header_lines(@webhook), "\n") %></pre>
                <% end %>
              </div>
            </section>
          </div>

          <div class="space-y-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-3">
              <h2 class="text-lg font-semibold">Health</h2>
              <div class="flex items-center gap-2">
                <.badge color={test_status_color(@webhook.last_test_status)} variant="soft">
                  {test_status_label(@webhook.last_test_status)}
                </.badge>
                <span class="text-xs text-base-content/60">
                  {last_test_label(@webhook.last_tested_at)}
                </span>
              </div>
              <p class="text-sm text-base-content/70">{health_summary(@webhook.last_test_status)}</p>
              <%= if present?(@webhook.last_test_error) do %>
                <div class="rounded-xl border border-base-300 bg-base-200/40 p-3 text-xs">
                  {@webhook.last_test_error}
                </div>
              <% end %>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-3">
              <h2 class="text-lg font-semibold">Notes</h2>
              <p class="text-sm text-base-content/70">
                Keep responses fast: aim for under {@webhook.timeout_secs}s.
              </p>
              <p class="text-sm text-base-content/70">
                Use clear tool names for easy prompt calls.
              </p>
            </section>
          </div>
        </div>
      </div>

      <.modal
        id="delete-webhook-modal"
        class="w-full max-w-lg p-0"
        open={@delete_modal_open}
        on_close={JS.push("close-delete-modal")}
      >
        <div class="flex flex-col">
          <div class="flex items-start justify-between gap-4 border-b border-base-200 p-6">
            <div>
              <h3 class="text-lg font-semibold">Delete webhook</h3>
              <p class="text-sm text-base-content/70">
                This removes the webhook and detaches it from agents.
              </p>
            </div>
          </div>
          <div class="space-y-4 p-6">
            <p class="text-sm text-base-content/70">
              Are you sure you want to delete "{@webhook.name}"?
            </p>
            <div class="flex justify-end gap-2">
              <.button variant="ghost" phx-click="close-delete-modal">Cancel</.button>
              <.button variant="soft" phx-click="delete">Delete</.button>
            </div>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    webhook = Webhooks.get_webhook!(socket.assigns.current_scope.tenant.id, id)

    {:ok,
     socket
     |> assign(:webhook, webhook)
     |> assign(:payload_text, format_payload(webhook))
     |> assign(:delete_modal_open, false)}
  end

  @impl true
  def handle_event("test", _params, socket) do
    case Webhooks.test_webhook(socket.assigns.webhook) do
      {:ok, _webhook} ->
        {:noreply,
         socket
         |> put_flash(:info, "Webhook test succeeded.")
         |> refresh_webhook()}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Webhook test failed.")
         |> refresh_webhook()}
    end
  end

  @impl true
  def handle_event("open_delete", _params, socket) do
    {:noreply, assign(socket, :delete_modal_open, true)}
  end

  @impl true
  def handle_event("close-delete-modal", _params, socket) do
    {:noreply, assign(socket, :delete_modal_open, false)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Webhooks.delete_webhook(socket.assigns.webhook, socket.assigns.current_scope.user) do
      {:ok, _webhook} ->
        {:noreply,
         socket
         |> put_flash(:info, "Webhook deleted.")
         |> push_navigate(to: ~p"/agent-data")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to delete webhook.")}
    end
  end

  defp refresh_webhook(socket) do
    webhook =
      Webhooks.get_webhook!(socket.assigns.current_scope.tenant.id, socket.assigns.webhook.id)

    socket
    |> assign(:webhook, webhook)
    |> assign(:payload_text, format_payload(webhook))
  end

  defp format_payload(%{sample_payload: nil}), do: ""

  defp format_payload(%{sample_payload: payload}) when is_map(payload) do
    Jason.encode!(payload, pretty: true)
  end

  defp format_payload(_webhook), do: ""

  defp header_lines(webhook) do
    custom =
      (webhook.headers || %{})
      |> Map.new()
      |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
      |> Enum.sort()

    auth =
      if webhook.auth_type in [:bearer, "bearer"] do
        ["Authorization: Bearer ********"]
      else
        []
      end

    custom ++ auth
  end

  defp schema_properties(schema) when is_map(schema) do
    properties = Map.get(schema, "properties") || Map.get(schema, :properties) || %{}

    properties
    |> Enum.map(fn {name, meta} -> {to_string(name), meta || %{}} end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp schema_properties(_schema), do: []

  defp schema_required?(schema, name) when is_map(schema) do
    required = Map.get(schema, "required") || Map.get(schema, :required) || []
    name in Enum.map(required, &to_string/1)
  end

  defp schema_required?(_schema, _name), do: false

  defp schema_type(meta) when is_map(meta) do
    case Map.get(meta, "type") || Map.get(meta, :type) do
      nil -> "—"
      list when is_list(list) -> Enum.join(Enum.map(list, &to_string/1), ", ")
      value -> to_string(value)
    end
  end

  defp schema_type(_meta), do: "—"

  defp schema_description(meta) when is_map(meta) do
    Map.get(meta, "description") || Map.get(meta, :description) || "—"
  end

  defp schema_description(_meta), do: "—"

  defp sort_tags(tags) when is_list(tags) do
    Enum.sort_by(tags, &String.downcase(&1.name))
  end

  defp sort_tags(_tags), do: []

  defp tag_style(tag) do
    "border-color: #{tag.color}; color: #{tag.color}; background-color: #{tag_background_color(tag.color)};"
  end

  defp tag_background_color(color) when is_binary(color) do
    if String.starts_with?(color, "#") and String.length(color) == 7 do
      color <> "1A"
    else
      "transparent"
    end
  end

  defp tag_background_color(_color), do: "transparent"

  defp tag_dot_style(tag) do
    "background-color: #{tag.color};"
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:disabled), do: "warning"
  defp status_color("disabled"), do: "warning"
  defp status_color(_), do: "info"

  defp status_label(:active), do: "Active"
  defp status_label("active"), do: "Active"
  defp status_label(:disabled), do: "Disabled"
  defp status_label("disabled"), do: "Disabled"

  defp status_label(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.capitalize()

  defp status_label(value) when is_binary(value), do: String.capitalize(value)

  defp test_status_color("success"), do: "success"
  defp test_status_color(:success), do: "success"
  defp test_status_color("error"), do: "danger"
  defp test_status_color(:error), do: "danger"
  defp test_status_color(nil), do: "info"
  defp test_status_color(_), do: "info"

  defp test_status_label("success"), do: "Success"
  defp test_status_label(:success), do: "Success"
  defp test_status_label("error"), do: "Error"
  defp test_status_label(:error), do: "Error"
  defp test_status_label(nil), do: "Not tested"
  defp test_status_label(value) when is_binary(value), do: String.capitalize(value)

  defp test_status_label(value) when is_atom(value),
    do: value |> Atom.to_string() |> String.capitalize()

  defp health_summary("success"), do: "Connection healthy."
  defp health_summary(:success), do: "Connection healthy."
  defp health_summary("error"), do: "Last test failed. Recheck the endpoint and auth."
  defp health_summary(:error), do: "Last test failed. Recheck the endpoint and auth."
  defp health_summary(nil), do: "Run a test to validate the webhook."
  defp health_summary(_), do: "Review the latest test result."

  defp last_test_label(nil), do: "Not tested yet"

  defp last_test_label(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M")
  end

  defp last_test_label(_), do: "Not tested yet"

  defp auth_label(:bearer), do: "Bearer token"
  defp auth_label("bearer"), do: "Bearer token"
  defp auth_label(:none), do: "No auth"
  defp auth_label("none"), do: "No auth"
  defp auth_label(value) when is_atom(value), do: value |> Atom.to_string() |> String.capitalize()
  defp auth_label(value) when is_binary(value), do: String.capitalize(value)

  defp auth_hint(:bearer), do: "Stored securely in secrets."
  defp auth_hint("bearer"), do: "Stored securely in secrets."
  defp auth_hint(:none), do: "Requests sent without auth."
  defp auth_hint("none"), do: "Requests sent without auth."
  defp auth_hint(_), do: "Review auth policy."

  defp method_label(value) when is_atom(value) do
    value |> Atom.to_string() |> String.upcase()
  end

  defp method_label(value) when is_binary(value), do: String.upcase(value)

  defp present?(nil), do: false
  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: true
end
