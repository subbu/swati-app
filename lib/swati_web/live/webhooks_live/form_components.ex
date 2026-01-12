defmodule SwatiWeb.WebhooksLive.FormComponents do
  use SwatiWeb, :html

  attr :form, :any, required: true
  attr :method_options, :list, required: true
  attr :status_options, :list, required: true

  def basics_section(assigns) do
    ~H"""
    <div>
      <h2 class="font-semibold text-foreground">Basics</h2>
      <p class="text-sm text-foreground-softer">
        Name the webhook and where it should send requests.
      </p>
      <div class="mt-6 w-full max-w-3xl space-y-6">
        <div class="grid gap-4 md:grid-cols-2">
          <.input field={@form[:name]} label="Name" required />
          <.input field={@form[:endpoint_url]} label="Endpoint URL" required />
          <.select field={@form[:http_method]} label="Method" options={@method_options} />
          <.input field={@form[:timeout_secs]} label="Timeout (seconds)" type="number" />
          <.select field={@form[:status]} label="Status" options={@status_options} />
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :tool_name_locked, :boolean, required: true

  def tool_section(assigns) do
    ~H"""
    <div>
      <h2 class="font-semibold text-foreground">Tool definition</h2>
      <p class="text-sm text-foreground-softer">
        Describe how agents should call this webhook.
      </p>
      <div class="mt-6 w-full max-w-3xl space-y-6">
        <div class="grid gap-4 md:grid-cols-2">
          <div class="space-y-2">
            <.input field={@form[:tool_name]} label="Tool name" required readonly={@tool_name_locked} />
            <p :if={@tool_name_locked} class="text-xs text-foreground-softer">
              Tool name locks once attached to an agent.
            </p>
          </div>
          <.input field={@form[:description]} label="Description" />
        </div>
      </div>
    </div>
    """
  end

  attr :tags, :list, required: true
  attr :selected_tag_ids, :list, required: true
  attr :target, :any, required: true

  def tags_section(assigns) do
    ~H"""
    <div>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="font-semibold text-foreground">Tags</h2>
          <p class="text-sm text-foreground-softer">
            Group webhooks with simple labels.
          </p>
        </div>
        <.button
          id="webhook-open-tag-modal"
          type="button"
          variant="ghost"
          phx-click="open-tag-modal"
          phx-target={@target}
        >
          New tag
        </.button>
      </div>

      <div class="mt-6">
        <%= if @tags == [] do %>
          <p class="text-sm text-foreground-softer">No tags yet. Create one to organize webhooks.</p>
        <% else %>
          <.checkbox_group
            name="webhook[tag_ids]"
            value={@selected_tag_ids}
            variant="card"
            class="flex flex-wrap gap-2"
          >
            <:checkbox :for={tag <- @tags} value={tag.id} class="p-0">
              <span
                class="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs font-semibold"
                style={tag_chip_style(tag.color)}
              >
                <span class="h-2 w-2 rounded-full" style={"background-color: #{tag.color};"}></span>
                {tag.name}
              </span>
            </:checkbox>
          </.checkbox_group>
        <% end %>
      </div>
    </div>
    """
  end

  attr :inputs, :list, required: true
  attr :input_type_options, :list, required: true
  attr :payload_preview, :string, required: true
  attr :target, :any, required: true

  def inputs_section(assigns) do
    ~H"""
    <div>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="font-semibold text-foreground">Inputs</h2>
          <p class="text-sm text-foreground-softer">
            Define the fields your webhook expects.
          </p>
        </div>
        <.button
          id="webhook-add-input"
          type="button"
          variant="ghost"
          phx-click="add_input"
          phx-target={@target}
        >
          Add input
        </.button>
      </div>

      <div class="mt-6 space-y-4">
        <div
          :if={@inputs == []}
          class="rounded-xl border border-dashed border-base-200 p-6 text-sm text-foreground-softer"
        >
          No inputs yet. Add fields so agents know what to send.
        </div>

        <div class="space-y-3">
          <div
            :for={{input, index} <- Enum.with_index(@inputs)}
            class="rounded-xl border border-base-200 bg-base-100 p-4 space-y-3"
          >
            <div class="grid gap-4 md:grid-cols-3">
              <.input name={"webhook[inputs][#{index}][name]"} label="Name" value={input["name"]} />
              <.select
                name={"webhook[inputs][#{index}][type]"}
                label="Type"
                options={@input_type_options}
                value={input["type"]}
              />
              <.switch
                name={"webhook[inputs][#{index}][required]"}
                label="Required"
                checked={input["required"]}
              />
            </div>
            <div class="grid gap-4 md:grid-cols-2">
              <.input
                name={"webhook[inputs][#{index}][description]"}
                label="Description"
                value={input["description"]}
              />
              <.input
                name={"webhook[inputs][#{index}][example]"}
                label="Example"
                value={input["example"]}
              />
            </div>
            <div class="flex justify-end">
              <.button
                type="button"
                variant="ghost"
                phx-click="remove_input"
                phx-value-index={index}
                phx-target={@target}
              >
                Remove
              </.button>
            </div>
          </div>
        </div>

        <div class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-foreground-softer">
            Payload preview
          </p>
          <p class="text-xs text-foreground-softer">
            Examples build the sample payload sent during tests.
          </p>
          <%= if @payload_preview == "" do %>
            <p class="text-sm text-foreground-softer">No sample payload yet.</p>
          <% else %>
            <pre
              class="rounded-xl border border-base-200 bg-base-100 p-3 text-xs"
              phx-no-curly-interpolation
            ><%= @payload_preview %></pre>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :auth_type_options, :list, required: true
  attr :auth_token, :string, required: true
  attr :header_entries, :list, required: true
  attr :target, :any, required: true

  def auth_section(assigns) do
    ~H"""
    <div>
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 class="font-semibold text-foreground">Authentication & headers</h2>
          <p class="text-sm text-foreground-softer">
            Add any auth tokens or extra headers your endpoint requires.
          </p>
        </div>
        <.button
          id="webhook-add-header"
          type="button"
          variant="ghost"
          phx-click="add_header"
          phx-target={@target}
        >
          Add header
        </.button>
      </div>

      <div class="mt-6 w-full max-w-3xl space-y-6">
        <div class="grid gap-4 md:grid-cols-2">
          <.select field={@form[:auth_type]} label="Auth type" options={@auth_type_options} />
          <.input name="webhook[auth_token]" label="Bearer token" value={@auth_token} />
        </div>

        <div
          :if={@header_entries == []}
          class="rounded-xl border border-dashed border-base-200 p-6 text-sm text-foreground-softer"
        >
          No custom headers yet.
        </div>

        <div class="space-y-3">
          <div
            :for={{header, index} <- Enum.with_index(@header_entries)}
            class="rounded-xl border border-base-200 bg-base-100 p-4"
          >
            <div class="grid gap-4 md:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_auto] items-end">
              <.input
                name={"webhook[header_entries][#{index}][key]"}
                label="Header"
                value={header["key"]}
              />
              <.input
                name={"webhook[header_entries][#{index}][value]"}
                label="Value"
                value={header["value"]}
              />
              <.button
                type="button"
                variant="ghost"
                phx-click="remove_header"
                phx-value-index={index}
                phx-target={@target}
              >
                Remove
              </.button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :tag_form, :any, required: true
  attr :tag_modal_open, :boolean, required: true
  attr :tag_palette_options, :list, required: true
  attr :target, :any, required: true

  def tag_modal(assigns) do
    ~H"""
    <.modal
      id="tag-create-modal"
      class="w-full max-w-lg p-0"
      open={@tag_modal_open}
      on_close={JS.push("close-tag-modal", target: @target)}
    >
      <div class="flex flex-col">
        <div class="flex items-start justify-between gap-4 border-b border-base-200 p-6">
          <div>
            <h3 class="text-lg font-semibold">New tag</h3>
            <p class="text-sm text-base-content/70">
              Create a tag to group related webhooks.
            </p>
          </div>
        </div>
        <div class="p-6">
          <.form for={@tag_form} id="tag-form" phx-submit="create-tag" phx-target={@target}>
            <div class="space-y-4">
              <.input field={@tag_form[:name]} label="Tag name" required />
              <.radio_group
                field={@tag_form[:color]}
                label="Color"
                variant="card"
                class="grid grid-cols-2 gap-2 sm:grid-cols-4"
              >
                <:radio :for={option <- @tag_palette_options} value={option.value} class="p-3">
                  <div class="flex items-center gap-2">
                    <span class="h-3 w-3 rounded-full" style={"background-color: #{option.value};"}>
                    </span>
                    <span class="text-sm">{option.name}</span>
                  </div>
                </:radio>
              </.radio_group>
            </div>
            <div class="mt-6 flex justify-end gap-2">
              <.button
                variant="ghost"
                type="button"
                phx-click="close-tag-modal"
                phx-target={@target}
              >
                Cancel
              </.button>
              <.button type="submit">Create tag</.button>
            </div>
          </.form>
        </div>
      </div>
    </.modal>
    """
  end

  defp tag_chip_style(color) when is_binary(color) do
    background =
      if String.starts_with?(color, "#") and String.length(color) == 7 do
        color <> "1A"
      else
        "transparent"
      end

    "border-color: #{color}; color: #{color}; background-color: #{background};"
  end

  defp tag_chip_style(_color), do: ""
end
