defmodule SwatiWeb.InboundEmailLive.Components do
  use SwatiWeb, :html

  alias SwatiWeb.InboundEmailLive.Helpers

  # ──────────────────────────────────────────────
  # Shared layout: page header + sub-navigation
  # ──────────────────────────────────────────────

  attr :active_tab, :string, required: true
  attr :inbound_enabled, :boolean, default: true
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="space-y-4">
      <header class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 class="text-2xl font-semibold text-foreground tracking-tight">Inbound Email</h1>
          <p class="text-sm text-foreground-softer mt-0.5">{tab_description(@active_tab)}</p>
        </div>
        <div :if={@actions != []} class="flex items-center gap-2">
          {render_slot(@actions)}
        </div>
      </header>

      <nav class="flex gap-1 border-b border-base -mb-px overflow-x-auto">
        <.tab_link
          label="Setup"
          icon="hero-cog-6-tooth"
          href={~p"/inbound-email/setup"}
          active={@active_tab == "setup"}
        />
        <.tab_link
          label="Inbox"
          icon="hero-inbox"
          href={~p"/inbound-email/inbox"}
          active={@active_tab == "inbox"}
        />
        <.tab_link
          label="Activity"
          icon="hero-clock"
          href={~p"/inbound-email/activity"}
          active={@active_tab == "activity"}
        />
        <.tab_link
          label="Preview"
          icon="hero-beaker"
          href={~p"/inbound-email/preview"}
          active={@active_tab == "preview"}
        />
      </nav>

      <div
        :if={!@inbound_enabled}
        class="flex items-center gap-2 rounded-lg border border-warning/30 bg-warning/5 px-4 py-3 text-sm text-foreground"
      >
        <.icon name="hero-exclamation-triangle" class="size-4 text-warning shrink-0" />
        <span>
          Inbound connectors are disabled. The <code class="text-xs bg-base-200 px-1.5 py-0.5 rounded">inbound_connectors_v1</code> flag is off — webhook endpoints will return 404.
        </span>
      </div>
    </div>
    """
  end

  defp tab_description("setup"), do: "Configure connectors, routing rules, and address bindings."
  defp tab_description("inbox"), do: "Browse inbound and outbound email messages."
  defp tab_description("activity"), do: "Monitor delivery processing and email threads."
  defp tab_description("preview"), do: "Test how emails would be routed."
  defp tab_description(_), do: ""

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :href, :string, required: true
  attr :active, :boolean, default: false

  defp tab_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={[
        "flex items-center gap-1.5 px-3 py-2.5 text-sm font-medium whitespace-nowrap border-b-2 -mb-px transition-colors",
        if(@active,
          do: "border-primary text-foreground",
          else: "border-transparent text-foreground-softer hover:text-foreground hover:border-base-300"
        )
      ]}
    >
      <.icon name={@icon} class="size-4" />
      {@label}
    </.link>
    """
  end

  # ──────────────────────────────────────────────
  # Section header with optional action
  # ──────────────────────────────────────────────

  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  def section_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between gap-3">
      <div>
        <h2 class="text-base font-semibold text-foreground">{@title}</h2>
        <p :if={@description} class="text-sm text-foreground-softer mt-0.5">{@description}</p>
      </div>
      <div :if={@action != []}>{render_slot(@action)}</div>
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Empty state
  # ──────────────────────────────────────────────

  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 text-center">
      <div class="flex items-center justify-center size-12 rounded-full bg-base-200 mb-4">
        <.icon name={@icon} class="size-6 text-foreground-softer" />
      </div>
      <h3 class="text-sm font-semibold text-foreground">{@title}</h3>
      <p :if={@description} class="text-sm text-foreground-softer mt-1 max-w-sm">{@description}</p>
      <div :if={@action != []} class="mt-4">{render_slot(@action)}</div>
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Connector card
  # ──────────────────────────────────────────────

  attr :connector, :map, required: true
  attr :agents, :list, required: true

  def connector_card(assigns) do
    ~H"""
    <article class="rounded-lg border border-base bg-base p-4 space-y-3 group">
      <div class="flex items-start justify-between gap-3">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center size-9 rounded-lg bg-info/10">
            <.icon name="hero-inbox-arrow-down" class="size-5 text-info" />
          </div>
          <div>
            <div class="font-medium text-foreground">{@connector.name}</div>
            <div class="text-xs text-foreground-softer capitalize">{@connector.provider}</div>
          </div>
        </div>

        <.dropdown>
          <:toggle>
            <button class="flex items-center justify-center size-8 rounded-md text-foreground-softer hover:text-foreground hover:bg-base-200 transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100">
              <.icon name="hero-ellipsis-vertical" class="size-5" />
            </button>
          </:toggle>
          <.dropdown_link phx-click={Fluxon.open_dialog("update-secret-sheet-#{@connector.id}")}>
            Update signing secret
          </.dropdown_link>
          <.dropdown_link
            phx-click="delete_connector"
            phx-value-id={@connector.id}
            data-confirm="Delete this connector? This cannot be undone."
            class="text-danger"
          >
            Delete connector
          </.dropdown_link>
        </.dropdown>
      </div>

      <div class="space-y-2">
        <div class="flex items-center gap-2 text-xs text-foreground-softer">
          <span class="font-medium uppercase tracking-wider">Webhook URL</span>
        </div>
        <div class="flex items-center gap-2">
          <code class="flex-1 rounded-md bg-base-200 px-3 py-2 text-xs text-foreground break-all font-mono">
            {Swati.Inbound.webhook_url(@connector)}
          </code>
          <button
            phx-click={
              JS.dispatch("phx:copy", detail: %{text: Swati.Inbound.webhook_url(@connector)})
            }
            class="shrink-0 flex items-center justify-center size-8 rounded-md text-foreground-softer hover:text-foreground hover:bg-base-200 transition-colors"
            title="Copy webhook URL"
          >
            <.icon name="hero-clipboard-document" class="size-4" />
          </button>
        </div>
      </div>

      <div class="flex flex-wrap gap-x-6 gap-y-1 text-sm pt-1 border-t border-base">
        <div class="flex items-center gap-1.5">
          <span class="text-foreground-softer">Agent:</span>
          <span class="text-foreground">
            {Helpers.resolve_agent_name(@connector.default_agent_id, @agents) || "None"}
          </span>
        </div>
        <div :if={@connector.default_endpoint_address} class="flex items-center gap-1.5">
          <span class="text-foreground-softer">Endpoint:</span>
          <span class="text-foreground">{@connector.default_endpoint_address}</span>
        </div>
      </div>

      <%!-- Inline secret update sheet --%>
      <.sheet
        id={"update-secret-sheet-#{@connector.id}"}
        placement="right"
        class="w-full max-w-sm"
      >
        <div class="p-4 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Update Signing Secret</h2>
            <p class="text-sm text-foreground-softer">
              Update the signing secret for {@connector.name}.
            </p>
          </div>

          <form phx-submit="update_connector_secret" class="space-y-3">
            <input type="hidden" name="connector_id" value={@connector.id} />
            <.input
              name="signing_secret"
              type="password"
              label="New signing secret"
              placeholder="whsec_..."
              required
            />
            <.button type="submit" variant="solid" class="w-full">Update secret</.button>
          </form>
        </div>
      </.sheet>
    </article>
    """
  end

  # ──────────────────────────────────────────────
  # Rule card
  # ──────────────────────────────────────────────

  attr :rule, :map, required: true
  attr :agents, :list, required: true

  def rule_card(assigns) do
    assigns = assign(assigns, :predicates, Helpers.format_predicates(assigns.rule.predicates))

    ~H"""
    <article class="rounded-lg border border-base bg-base p-4 group">
      <div class="flex items-start justify-between gap-3">
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="font-medium text-foreground">{@rule.name}</span>
            <.badge size="xs" variant="soft" color={Helpers.action_color(@rule.action)}>
              {@rule.action}
            </.badge>
            <span class="text-xs text-foreground-softer">
              Priority {@rule.priority}
            </span>
          </div>
          <div class="text-sm text-foreground-softer mt-1">
            Agent: {Helpers.resolve_agent_name(@rule.agent_id, @agents) || (@rule.agent && @rule.agent.name) || "-"}
          </div>
        </div>

        <.button
          variant="ghost"
          size="xs"
          phx-click="delete_rule"
          phx-value-id={@rule.id}
          data-confirm="Delete this rule?"
          class="opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity"
        >
          <.icon name="hero-trash" class="size-3.5" />
        </.button>
      </div>

      <div :if={@predicates != []} class="flex flex-wrap gap-1.5 mt-3">
        <span
          :for={{label, value} <- @predicates}
          class="inline-flex items-center gap-1 rounded-md bg-base-200 px-2 py-1 text-xs text-foreground"
        >
          <span class="text-foreground-softer">{label}:</span>
          <span class="font-medium">{value}</span>
        </span>
      </div>
    </article>
    """
  end

  # ──────────────────────────────────────────────
  # Delivery card (for Activity page)
  # ──────────────────────────────────────────────

  attr :delivery, :map, required: true
  attr :agents, :list, required: true

  def delivery_card(assigns) do
    ~H"""
    <article class={[
      "rounded-lg border bg-base p-4 space-y-2",
      delivery_border_class(@delivery.status)
    ]}>
      <div class="flex items-start justify-between gap-3">
        <div class="flex items-center gap-2.5 min-w-0">
          <.badge size="sm" variant="soft" color={Helpers.delivery_status_color(@delivery.status)}>
            {@delivery.status}
          </.badge>
          <span class="text-sm font-medium text-foreground truncate">
            {Helpers.delivery_subject(@delivery)}
          </span>
        </div>
        <span class="text-xs text-foreground-softer whitespace-nowrap shrink-0">
          {Helpers.relative_time(@delivery.received_at)}
        </span>
      </div>

      <div class="text-sm text-foreground-softer">
        <span>{Helpers.delivery_from(@delivery)}</span>
        <span class="mx-1.5 text-foreground-softer/50">&rarr;</span>
        <span>{Helpers.delivery_to(@delivery)}</span>
      </div>

      <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-foreground-softer pt-2 border-t border-base">
        <span>
          <span class="text-foreground-softer">Owner:</span>
          <span class="text-foreground">{Helpers.delivery_owner_name(@delivery, @agents)}</span>
        </span>
        <span>
          <span class="text-foreground-softer">Route:</span>
          <span class="text-foreground">{Helpers.delivery_route_reason(@delivery)}</span>
        </span>
        <.continuity_indicator value={Helpers.delivery_continuity(@delivery)} />
        <.link
          :if={Helpers.delivery_session_id(@delivery)}
          navigate={~p"/sessions/#{Helpers.delivery_session_id(@delivery)}"}
          class="link"
        >
          Session
        </.link>
        <.link
          :if={Helpers.delivery_case_id(@delivery)}
          navigate={~p"/cases/#{Helpers.delivery_case_id(@delivery)}"}
          class="link"
        >
          Case
        </.link>

        <.button
          :if={Helpers.delivery_replayable?(@delivery)}
          variant="ghost"
          size="xs"
          phx-click="replay_delivery"
          phx-value-id={@delivery.id}
          class="ml-auto"
        >
          <.icon name="hero-arrow-path" class="size-3" /> Replay
        </.button>
      </div>
    </article>
    """
  end

  defp delivery_border_class(:failed), do: "border-danger/30"
  defp delivery_border_class(:processing), do: "border-warning/30"
  defp delivery_border_class(_), do: "border-base"

  attr :value, :atom, default: nil

  defp continuity_indicator(assigns) do
    ~H"""
    <span :if={@value} class="flex items-center gap-1">
      <span class="text-foreground-softer">Continuity:</span>
      <span class={[
        "flex items-center gap-0.5",
        if(@value == :hit, do: "text-success", else: "text-foreground-softer")
      ]}>
        <span class={[
          "inline-block size-1.5 rounded-full",
          if(@value == :hit, do: "bg-success", else: "bg-foreground-softer/40")
        ]} />
        {to_string(@value)}
      </span>
    </span>
    """
  end

  # ──────────────────────────────────────────────
  # Message list item (for Inbox)
  # ──────────────────────────────────────────────

  attr :message, :map, required: true
  attr :selected, :boolean, default: false

  def message_item(assigns) do
    ~H"""
    <button
      phx-click="select_message"
      phx-value-id={@message.id}
      class={[
        "w-full text-left px-4 py-3 border-b border-base transition-colors cursor-pointer",
        if(@selected,
          do: "bg-primary/5",
          else: "hover:bg-base-200/50"
        )
      ]}
    >
      <div class="flex items-start gap-3">
        <.icon
          name={direction_icon_name(@message.type)}
          class={"size-4 mt-0.5 shrink-0 #{direction_icon_class(@message.type)}"}
        />

        <div class="flex-1 min-w-0">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm font-medium text-foreground truncate">
              {message_sender(@message)}
            </span>
            <span class="text-xs text-foreground-softer whitespace-nowrap shrink-0">
              {Helpers.relative_time(@message.ts)}
            </span>
          </div>
          <div class="text-sm text-foreground truncate mt-0.5">
            {message_subject(@message)}
          </div>
          <div :if={@message.agent_name} class="flex items-center gap-1 mt-1">
            <.icon name="hero-user-circle" class="size-3.5 text-foreground-softer shrink-0" />
            <span class="text-xs text-foreground-softer truncate">
              {@message.agent_name}
            </span>
          </div>
        </div>
      </div>
    </button>
    """
  end

  # ──────────────────────────────────────────────
  # Message detail pane (for Inbox)
  # ──────────────────────────────────────────────

  attr :message, :map, required: true
  attr :tenant, :map, required: true
  attr :on_close, :any, default: nil

  def message_detail(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <%!-- Mobile back button --%>
      <div :if={@on_close} class="lg:hidden flex items-center gap-2 px-4 py-3 border-b border-base">
        <button phx-click={@on_close} class="flex items-center gap-1 text-sm text-foreground-softer hover:text-foreground">
          <.icon name="hero-arrow-left" class="size-4" />
          Back
        </button>
      </div>

      <div class="flex-1 overflow-y-auto p-5 space-y-5">
        <%!-- Subject --%>
        <div>
          <h2 class="text-lg font-semibold text-foreground leading-snug">
            {message_subject(@message)}
          </h2>
          <div class="flex items-center gap-2 mt-2">
            <div class="flex items-center gap-1.5">
              <.icon
                name={direction_icon_name(@message.type)}
                class={"size-4 #{direction_icon_class(@message.type)}"}
              />
              <span class="text-sm text-foreground">{direction_label(@message.type)}</span>
            </div>
            <span class="text-sm text-foreground-softer">
              {format_full_datetime(@message.ts, @tenant)}
            </span>
          </div>
        </div>

        <%!-- From / To --%>
        <div class="rounded-lg border border-base p-4 space-y-2 text-sm">
          <div class="flex gap-2">
            <span class="text-foreground-softer w-10 shrink-0">From</span>
            <span class="text-foreground font-medium">{message_from(@message)}</span>
          </div>
          <div class="flex gap-2">
            <span class="text-foreground-softer w-10 shrink-0">To</span>
            <span class="text-foreground">{message_to(@message)}</span>
          </div>
        </div>

        <%!-- Body --%>
        <% body = Helpers.message_body(@message.payload) %>
        <div :if={body} class="prose prose-sm max-w-none text-foreground">
          <pre class="whitespace-pre-wrap text-sm font-sans bg-transparent p-0 border-0">{body}</pre>
        </div>
        <div :if={!body} class="text-sm text-foreground-softer italic">
          No message body available.
        </div>

        <%!-- Metadata --%>
        <div class="rounded-lg border border-base p-4 space-y-2">
          <h3 class="text-xs font-semibold uppercase tracking-wider text-foreground-softer">Details</h3>
          <div class="grid grid-cols-2 gap-y-2 gap-x-4 text-sm">
            <div>
              <span class="text-foreground-softer">Owner</span>
              <div class="text-foreground font-medium">
                {@message.agent_name || @message.agent_id || "-"}
              </div>
            </div>
            <div>
              <span class="text-foreground-softer">Case</span>
              <div>
                <.link :if={@message.case_id} navigate={~p"/cases/#{@message.case_id}"} class="link font-medium">
                  {@message.case_id}
                </.link>
                <span :if={!@message.case_id} class="text-foreground-softer">-</span>
              </div>
            </div>
            <div>
              <span class="text-foreground-softer">Thread</span>
              <div>
                <.link navigate={~p"/sessions/#{@message.session_id}"} class="link font-medium">
                  {@message.session_external_id || @message.session_id}
                </.link>
              </div>
            </div>
          </div>
        </div>

        <div class="pt-2">
          <.link navigate={~p"/sessions/#{@message.session_id}"} class="btn btn-outline btn-sm">
            <.icon name="hero-arrow-top-right-on-square" class="size-4" />
            Open session
          </.link>
        </div>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Status filter tabs (for Activity page)
  # ──────────────────────────────────────────────

  attr :current, :string, default: "all"
  attr :options, :list, required: true

  def status_filter_tabs(assigns) do
    ~H"""
    <div class="flex gap-1 flex-wrap">
      <button
        :for={{label, value} <- @options}
        phx-click="filter_status"
        phx-value-status={value}
        class={[
          "px-3 py-1.5 rounded-md text-xs font-medium transition-colors",
          if(@current == value,
            do: "bg-foreground text-base",
            else: "text-foreground-softer hover:text-foreground hover:bg-base-200"
          )
        ]}
      >
        {label}
      </button>
    </div>
    """
  end

  # ──────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────

  defp message_subject(message) do
    payload = message.payload || %{}
    payload["subject"] || payload[:subject] || "(no subject)"
  end

  defp message_sender(message) do
    payload = message.payload || %{}
    payload["from"] || payload[:from] || "-"
  end

  defp message_from(message) do
    payload = message.payload || %{}
    payload["from"] || payload[:from] || "-"
  end

  defp message_to(message) do
    payload = message.payload || %{}
    to = payload["to"] || payload[:to] || []
    List.wrap(to) |> Enum.join(", ")
  end

  defp direction_label("channel.message.received"), do: "Inbound"
  defp direction_label("channel.message.sent"), do: "Outbound"
  defp direction_label(_), do: "Message"

  defp direction_icon_name("channel.message.received"), do: "hero-arrow-down-left"
  defp direction_icon_name("channel.message.sent"), do: "hero-arrow-up-right"
  defp direction_icon_name(_), do: "hero-minus"

  defp direction_icon_class("channel.message.received"), do: "text-emerald-500"
  defp direction_icon_class("channel.message.sent"), do: "text-sky-500"
  defp direction_icon_class(_), do: "text-foreground-softer"

  defp format_full_datetime(nil, _tenant), do: "-"

  defp format_full_datetime(%DateTime{} = ts, tenant) do
    SwatiWeb.Formatting.datetime(ts, tenant)
  end

  defp format_full_datetime(_, _), do: "-"
end
