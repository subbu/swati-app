defmodule SwatiWeb.AgentsLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Avatars
  alias Swati.Calls.Dashboard, as: CallsDashboard

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="agents-index" class="space-y-6">
        <%!-- Page Header --%>
        <header class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div class="flex items-center gap-4">
            <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-500/20 to-fuchsia-500/20 ring-1 ring-violet-500/10">
              <.icon name="hero-user-group" class="h-6 w-6 text-violet-600 dark:text-violet-400" />
            </div>
            <div>
              <h1 class="text-2xl font-bold tracking-tight text-base-content">Agents</h1>
              <p class="text-sm text-base-content/60">
                Your AI voice agents — {@all_agents_count} total
              </p>
            </div>
          </div>
          <.button navigate={~p"/agents/new"} variant="solid">
            <.icon name="hero-plus" class="mr-1.5 h-4 w-4" /> New agent
          </.button>
        </header>

        <%!-- Search & Filter Bar --%>
        <section class="rounded-xl border border-base-300 bg-base-100">
          <div class="flex flex-wrap items-center gap-2 px-4 py-3">
            <%!-- Search Input --%>
            <.form for={@filter_form} id="agents-filter" phx-change="filter" class="flex-1 min-w-[200px] max-w-sm">
              <.input
                field={@filter_form[:query]}
                type="text"
                placeholder="Search agents..."
                phx-debounce="300"
              >
                <:inner_prefix>
                  <.icon name="hero-magnifying-glass" class="icon" />
                </:inner_prefix>
              </.input>
            </.form>

            <%!-- Status Filter --%>
            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-funnel" class="icon" />
                  <span class="hidden sm:inline ml-1">
                    {status_filter_label(@filters)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"status" => ""}})}>
                All statuses
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- status_options()}
                phx-click={JS.push("filter", value: %{filters: %{"status" => value}})}
              >
                <span class={["mr-2 inline-block h-2 w-2 rounded-full", status_dot_for_filter(value)]}></span>
                {label}
              </.dropdown_button>
            </.dropdown>

            <%!-- Language Filter --%>
            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-language" class="icon" />
                  <span class="hidden sm:inline ml-1">
                    {language_filter_label(@filters)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{filters: %{"language" => ""}})}>
                All languages
              </.dropdown_button>
              <.dropdown_button
                :for={{label, value} <- language_options(@all_agents)}
                phx-click={JS.push("filter", value: %{filters: %{"language" => value}})}
              >
                {language_flag(value)} {label}
              </.dropdown_button>
            </.dropdown>

            <%!-- Sort Dropdown --%>
            <.dropdown placement="bottom-start">
              <:toggle>
                <.button variant="dashed">
                  <.icon name="hero-arrows-up-down" class="icon" />
                  <span class="hidden sm:inline ml-1">
                    {sort_label(@sort)}
                  </span>
                </.button>
              </:toggle>
              <.dropdown_button
                :for={{label, value} <- sort_options()}
                phx-click={JS.push("sort", value: %{sort: value})}
              >
                <.icon
                  :if={@sort.field == value}
                  name={if @sort.direction == "asc", do: "hero-arrow-up", else: "hero-arrow-down"}
                  class="mr-2 h-3 w-3"
                />
                <span :if={@sort.field != value} class="mr-2 w-3"></span>
                {label}
              </.dropdown_button>
            </.dropdown>

            <%!-- View Toggle --%>
            <div class="hidden sm:flex items-center rounded-lg border border-base-300 p-0.5">
              <button
                type="button"
                phx-click="set_view"
                phx-value-view="grid"
                class={[
                  "rounded-md p-1.5 transition-colors",
                  @view_mode == "grid" && "bg-base-200 text-base-content",
                  @view_mode != "grid" && "text-base-content/50 hover:text-base-content"
                ]}
              >
                <.icon name="hero-squares-2x2" class="h-4 w-4" />
              </button>
              <button
                type="button"
                phx-click="set_view"
                phx-value-view="list"
                class={[
                  "rounded-md p-1.5 transition-colors",
                  @view_mode == "list" && "bg-base-200 text-base-content",
                  @view_mode != "list" && "text-base-content/50 hover:text-base-content"
                ]}
              >
                <.icon name="hero-list-bullet" class="h-4 w-4" />
              </button>
            </div>

            <%!-- Reset Filters --%>
            <%= if @filters_active do %>
              <.button
                size="sm"
                variant="ghost"
                type="button"
                phx-click="reset_filters"
                aria-label="Reset filters"
              >
                <.icon name="hero-x-mark" class="icon" />
                <span class="hidden sm:inline ml-1">Reset</span>
              </.button>
            <% end %>
          </div>

          <%!-- Active Filter Pills --%>
          <%= if @filters_active do %>
            <div class="flex flex-wrap items-center gap-2 border-t border-base-200 px-4 py-2 bg-base-50">
              <span class="text-xs text-base-content/50">Showing:</span>
              <%= if @filters["status"] != "" do %>
                <.badge variant="soft" color="info" size="sm" class="gap-1">
                  {status_label(@filters["status"])}
                  <button
                    type="button"
                    phx-click={JS.push("filter", value: %{filters: %{"status" => ""}})}
                    class="ml-1 hover:text-base-content"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </.badge>
              <% end %>
              <%= if @filters["language"] != "" do %>
                <.badge variant="soft" color="info" size="sm" class="gap-1">
                  {language_flag(@filters["language"])} {@filters["language"]}
                  <button
                    type="button"
                    phx-click={JS.push("filter", value: %{filters: %{"language" => ""}})}
                    class="ml-1 hover:text-base-content"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </.badge>
              <% end %>
              <%= if @filters["query"] != "" do %>
                <.badge variant="soft" color="info" size="sm" class="gap-1">
                  "{@filters["query"]}"
                  <button
                    type="button"
                    phx-click={JS.push("filter", value: %{filters: %{"query" => ""}})}
                    class="ml-1 hover:text-base-content"
                  >
                    <.icon name="hero-x-mark" class="h-3 w-3" />
                  </button>
                </.badge>
              <% end %>
              <span class="text-xs text-base-content/40">
                {length(@filtered_agents)} of {@all_agents_count} agents
              </span>
            </div>
          <% end %>
        </section>

        <%!-- Agent Cards Grid or List --%>
        <%= if @filtered_agents == [] do %>
          <%= if @filters_active do %>
            <.no_results_state />
          <% else %>
            <.empty_state />
          <% end %>
        <% else %>
          <%= if @view_mode == "grid" do %>
            <div class="grid gap-5 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
              <.agent_card
                :for={agent <- @filtered_agents}
                agent={agent}
                avatar={Map.get(@avatars_by_agent, agent.id)}
                channels={Map.get(@channels_by_agent, agent.id, [])}
                stats={Map.get(@stats_by_agent, agent.id, %{})}
              />
            </div>
          <% else %>
            <div class="rounded-xl border border-base-300 bg-base-100 overflow-hidden">
              <.table id="agents-table">
                <.table_head class="text-base-content/60">
                  <:col class="py-3 pl-4">Agent</:col>
                  <:col class="py-3">Status</:col>
                  <:col class="py-3">Language</:col>
                  <:col class="py-3">Channels</:col>
                  <:col class="py-3">Calls</:col>
                  <:col class="py-3">Talk Time</:col>
                  <:col class="py-3 pr-4"></:col>
                </.table_head>
                <.table_body>
                  <.table_row
                    :for={agent <- @filtered_agents}
                    class="hover:bg-base-50 transition-colors cursor-pointer"
                    phx-click="select_agent"
                    phx-value-id={agent.id}
                  >
                    <:cell class="py-3 pl-4">
                      <div class="flex items-center gap-3">
                        <div class="h-10 w-10 shrink-0 overflow-hidden rounded-xl border border-base-300 bg-base-200">
                          <%= if avatar_ready?(Map.get(@avatars_by_agent, agent.id)) do %>
                            <img
                              src={@avatars_by_agent[agent.id].output_url}
                              alt={agent.name}
                              class="h-full w-full object-cover"
                              loading="lazy"
                            />
                          <% else %>
                            <div class="flex h-full w-full items-center justify-center text-xs font-bold text-base-content/30">
                              {initials(agent.name)}
                            </div>
                          <% end %>
                        </div>
                        <div class="min-w-0">
                          <p class="font-semibold text-base-content truncate">{agent.name}</p>
                          <p class="text-xs text-base-content/50 truncate">{model_short(agent.llm_model)}</p>
                        </div>
                      </div>
                    </:cell>
                    <:cell class="py-3">
                      <.badge variant="soft" color={status_color(agent.status)} size="sm">
                        {status_label(agent.status)}
                      </.badge>
                    </:cell>
                    <:cell class="py-3">
                      <span class="text-sm">{language_flag(agent.language)} {agent.language}</span>
                    </:cell>
                    <:cell class="py-3">
                      <% channels = Map.get(@channels_by_agent, agent.id, []) %>
                      <%= if channels != [] do %>
                        <div class="flex items-center gap-1">
                          <.channel_pill :for={channel <- Enum.take(channels, 3)} channel={channel} />
                          <%= if length(channels) > 3 do %>
                            <span class="text-xs text-base-content/50">+{length(channels) - 3}</span>
                          <% end %>
                        </div>
                      <% else %>
                        <span class="text-xs text-base-content/40">—</span>
                      <% end %>
                    </:cell>
                    <:cell class="py-3">
                      <span class="text-sm font-medium">{Map.get(@stats_by_agent[agent.id] || %{}, :calls, 0)}</span>
                    </:cell>
                    <:cell class="py-3">
                      <span class="text-sm">{format_minutes(Map.get(@stats_by_agent[agent.id] || %{}, :minutes, 0))}</span>
                    </:cell>
                    <:cell class="py-3 pr-4 text-right">
                      <.dropdown placement="bottom-end">
                        <:toggle>
                          <.button size="sm" variant="ghost">
                            <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
                          </.button>
                        </:toggle>
                        <.dropdown_link navigate={~p"/agents/#{agent.id}/edit"}>
                          <.icon name="hero-pencil" class="icon" /> Edit agent
                        </.dropdown_link>
                        <.dropdown_button phx-click="select_agent" phx-value-id={agent.id}>
                          <.icon name="hero-eye" class="icon" /> View details
                        </.dropdown_button>
                        <.dropdown_link navigate={~p"/agents/#{agent.id}/versions"}>
                          <.icon name="hero-clock" class="icon" /> Version history
                        </.dropdown_link>
                      </.dropdown>
                    </:cell>
                  </.table_row>
                </.table_body>
              </.table>
            </div>
          <% end %>
        <% end %>
      </div>

      <%!-- Agent Detail Sheet --%>
      <.sheet
        id="agent-detail-sheet"
        placement="right"
        class="w-full max-w-xl"
        open={@sheet_open}
        on_close={JS.push("close_sheet")}
      >
        <%= if @selected_agent do %>
          <.agent_detail_panel
            agent={@selected_agent}
            avatar={Map.get(@avatars_by_agent, @selected_agent.id)}
            channels={Map.get(@channels_by_agent, @selected_agent.id, [])}
            stats={Map.get(@stats_by_agent, @selected_agent.id, %{})}
          />
        <% end %>
      </.sheet>
    </Layouts.app>
    """
  end

  # Agent Card Component - Photo-centric design
  attr :agent, :map, required: true
  attr :avatar, :map, default: nil
  attr :channels, :list, default: []
  attr :stats, :map, default: %{}

  defp agent_card(assigns) do
    ~H"""
    <div
      class="group relative flex flex-col overflow-hidden rounded-2xl border border-base-300 bg-base-100 transition-all duration-200 hover:shadow-lg hover:shadow-base-300/50 hover:-translate-y-0.5"
      phx-click="select_agent"
      phx-value-id={@agent.id}
    >
      <%!-- Avatar Hero Section --%>
      <div class="relative aspect-square overflow-hidden bg-gradient-to-br from-base-200 via-base-200/80 to-base-300">
        <%!-- Background pattern --%>
        <div class="absolute inset-0 opacity-30">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_50%_50%,rgba(139,92,246,0.1),transparent_70%)]">
          </div>
        </div>

        <%!-- Avatar Image or Placeholder --%>
        <%= if avatar_ready?(@avatar) do %>
          <img
            src={@avatar.output_url}
            alt={@agent.name}
            class="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
            loading="lazy"
          />
        <% else %>
          <div class="flex h-full w-full items-center justify-center">
            <span class="text-6xl font-bold text-base-content/20 transition-colors group-hover:text-base-content/30">
              {initials(@agent.name)}
            </span>
          </div>
        <% end %>

        <%!-- Status Badge Overlay --%>
        <div class="absolute right-3 top-3">
          <div class={[
            "flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-medium backdrop-blur-sm",
            status_badge_class(@agent.status)
          ]}>
            <span class={["h-1.5 w-1.5 rounded-full", status_dot_class(@agent.status)]}></span>
            {status_label(@agent.status)}
          </div>
        </div>

        <%!-- Channels Overlay --%>
        <%= if @channels != [] do %>
          <div class="absolute bottom-3 left-3 flex items-center gap-1">
            <.channel_pill :for={channel <- Enum.take(@channels, 3)} channel={channel} />
            <%= if length(@channels) > 3 do %>
              <span class="rounded-full bg-base-content/10 px-2 py-0.5 text-[10px] font-medium text-base-content/70 backdrop-blur-sm">
                +{length(@channels) - 3}
              </span>
            <% end %>
          </div>
        <% end %>

        <%!-- Quick Actions Overlay (on hover) --%>
        <div class="absolute inset-0 flex items-center justify-center gap-2 bg-base-content/0 opacity-0 transition-all duration-200 group-hover:bg-base-content/5 group-hover:opacity-100">
          <.link
            navigate={~p"/agents/#{@agent.id}/edit"}
            class="flex h-10 w-10 items-center justify-center rounded-full bg-base-100/90 text-base-content shadow-lg backdrop-blur-sm transition-transform hover:scale-110"
          >
            <.icon name="hero-pencil" class="h-4 w-4" />
          </.link>
          <button
            type="button"
            phx-click="select_agent"
            phx-value-id={@agent.id}
            class="flex h-10 w-10 items-center justify-center rounded-full bg-primary text-primary-content shadow-lg transition-transform hover:scale-110"
          >
            <.icon name="hero-eye" class="h-4 w-4" />
          </button>
        </div>
      </div>

      <%!-- Info Section --%>
      <div class="flex flex-1 flex-col p-4">
        <h3 class="font-semibold text-base-content truncate">{@agent.name}</h3>
        <p class="mt-0.5 text-xs text-base-content/50 truncate">
          {model_short(@agent.llm_model)} · {language_flag(@agent.language)} {@agent.language}
        </p>

        <%!-- Stats Row --%>
        <div class="mt-3 flex items-center gap-4 border-t border-base-200 pt-3">
          <.mini_stat icon="hero-phone" value={Map.get(@stats, :calls, 0)} label="calls" />
          <.mini_stat
            icon="hero-clock"
            value={format_minutes(Map.get(@stats, :minutes, 0))}
            label="mins"
          />
          <.mini_stat
            icon="hero-arrow-trending-up"
            value={format_percent(Map.get(@stats, :completion_rate, 0))}
            label="rate"
          />
        </div>
      </div>
    </div>
    """
  end

  # Mini Stat Component
  attr :icon, :string, required: true
  attr :value, :any, required: true
  attr :label, :string, required: true

  defp mini_stat(assigns) do
    ~H"""
    <div class="flex items-center gap-1.5 text-xs">
      <.icon name={@icon} class="h-3.5 w-3.5 text-base-content/40" />
      <span class="font-medium text-base-content">{@value}</span>
      <span class="text-base-content/40">{@label}</span>
    </div>
    """
  end

  # Channel Pill Component
  attr :channel, :map, required: true

  defp channel_pill(assigns) do
    ~H"""
    <.tooltip>
      <div class={[
        "flex h-6 w-6 items-center justify-center rounded-full backdrop-blur-sm",
        channel_pill_color(@channel.type)
      ]}>
        <.channel_icon channel={@channel.type} class="h-3 w-3" />
      </div>
      <:content>{@channel.name}</:content>
    </.tooltip>
    """
  end

  defp channel_pill_color(:voice), do: "bg-blue-500/90 text-white"
  defp channel_pill_color(:email), do: "bg-orange-500/90 text-white"
  defp channel_pill_color(:chat), do: "bg-teal-500/90 text-white"
  defp channel_pill_color(:whatsapp), do: "bg-green-500/90 text-white"
  defp channel_pill_color(_), do: "bg-base-content/20 text-base-content"

  # Empty State Component
  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center rounded-2xl border-2 border-dashed border-base-300 bg-base-100/50 py-16 text-center">
      <div class="flex h-16 w-16 items-center justify-center rounded-2xl bg-violet-100 dark:bg-violet-900/30">
        <.icon name="hero-user-plus" class="h-8 w-8 text-violet-600 dark:text-violet-400" />
      </div>
      <h3 class="mt-4 text-lg font-semibold text-base-content">No agents yet</h3>
      <p class="mt-1 max-w-sm text-sm text-base-content/60">
        Create your first AI agent to start handling voice calls, emails, and more.
      </p>
      <.button navigate={~p"/agents/new"} variant="solid" class="mt-6">
        <.icon name="hero-plus" class="mr-1.5 h-4 w-4" /> Create your first agent
      </.button>
    </div>
    """
  end

  # No Results State Component
  defp no_results_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center rounded-2xl border border-base-300 bg-base-100 py-12 text-center">
      <div class="flex h-12 w-12 items-center justify-center rounded-xl bg-base-200">
        <.icon name="hero-magnifying-glass" class="h-6 w-6 text-base-content/40" />
      </div>
      <h3 class="mt-4 text-base font-semibold text-base-content">No agents found</h3>
      <p class="mt-1 max-w-sm text-sm text-base-content/60">
        Try adjusting your search or filter criteria.
      </p>
      <.button variant="ghost" size="sm" phx-click="reset_filters" class="mt-4">
        <.icon name="hero-x-mark" class="mr-1.5 h-4 w-4" /> Clear all filters
      </.button>
    </div>
    """
  end

  # Agent Detail Panel (for sheet)
  attr :agent, :map, required: true
  attr :avatar, :map, default: nil
  attr :channels, :list, default: []
  attr :stats, :map, default: %{}

  defp agent_detail_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header with Avatar --%>
      <header class="flex items-start gap-4">
        <div class="relative">
          <div class="h-20 w-20 overflow-hidden rounded-2xl border-2 border-base-300 bg-base-200">
            <%= if avatar_ready?(@avatar) do %>
              <img src={@avatar.output_url} alt={@agent.name} class="h-full w-full object-cover" />
            <% else %>
              <div class="flex h-full w-full items-center justify-center">
                <span class="text-2xl font-bold text-base-content/30">{initials(@agent.name)}</span>
              </div>
            <% end %>
          </div>
          <div class={[
            "absolute -bottom-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full border-2 border-base-100",
            status_ring_bg(@agent.status)
          ]}>
            <.icon name={status_icon(@agent.status)} class="h-3 w-3 text-white" />
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <h2 class="text-xl font-bold text-base-content truncate">{@agent.name}</h2>
          <p class="text-sm text-base-content/60">
            {language_flag(@agent.language)} {language_name(@agent.language)}
          </p>
          <div class="mt-2 flex flex-wrap gap-2">
            <.badge variant="soft" color={status_color(@agent.status)} size="sm">
              {status_label(@agent.status)}
            </.badge>
            <.badge variant="soft" color="info" size="sm">
              v{@agent.published_version_id || "0"}
            </.badge>
          </div>
        </div>
      </header>

      <%!-- Stats Grid --%>
      <section class="grid grid-cols-3 gap-3">
        <.detail_stat label="Total Calls" value={Map.get(@stats, :calls, 0)} icon="hero-phone" />
        <.detail_stat
          label="Talk Time"
          value={format_duration(Map.get(@stats, :minutes, 0) * 60)}
          icon="hero-clock"
        />
        <.detail_stat
          label="Success Rate"
          value={format_percent(Map.get(@stats, :completion_rate, 0))}
          icon="hero-chart-bar"
        />
      </section>

      <%!-- Channels Section --%>
      <section class="space-y-3">
        <div class="flex items-center justify-between">
          <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
            Connected Channels
          </h3>
          <span class="text-xs text-base-content/40">{length(@channels)} active</span>
        </div>
        <%= if @channels == [] do %>
          <div class="rounded-xl border border-dashed border-base-300 bg-base-200/30 p-4 text-center">
            <p class="text-sm text-base-content/50">No channels connected</p>
            <.link
              navigate={~p"/agents/#{@agent.id}/edit"}
              class="mt-2 inline-flex text-sm text-primary hover:underline"
            >
              Connect channels
            </.link>
          </div>
        <% else %>
          <div class="space-y-2">
            <.channel_row :for={channel <- @channels} channel={channel} />
          </div>
        <% end %>
      </section>

      <%!-- Model & Voice Section --%>
      <section class="space-y-3">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
          Configuration
        </h3>
        <div class="rounded-xl border border-base-300 bg-base-200/30 p-4 space-y-3">
          <div class="flex items-center justify-between">
            <span class="text-sm text-base-content/70">LLM Model</span>
            <span class="text-sm font-mono text-base-content">{model_short(@agent.llm_model)}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-base-content/70">Voice</span>
            <span class="text-sm text-base-content">{@agent.voice_name}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm text-base-content/70">Provider</span>
            <span class="text-sm text-base-content capitalize">{@agent.voice_provider}</span>
          </div>
        </div>
      </section>

      <%!-- Actions --%>
      <div class="flex items-center gap-3 pt-4 border-t border-base-300">
        <.link navigate={~p"/agents/#{@agent.id}/edit"} class="flex-1">
          <.button variant="solid" class="w-full">
            <.icon name="hero-pencil" class="mr-1.5 h-4 w-4" /> Edit Agent
          </.button>
        </.link>
        <.link navigate={~p"/agents/#{@agent.id}/versions"}>
          <.button variant="ghost">
            <.icon name="hero-clock" class="h-4 w-4" />
          </.button>
        </.link>
      </div>
    </div>
    """
  end

  # Detail Stat Component
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true

  defp detail_stat(assigns) do
    ~H"""
    <div class="flex flex-col items-center rounded-xl border border-base-300 bg-base-200/30 p-3 text-center">
      <.icon name={@icon} class="h-4 w-4 text-base-content/40" />
      <p class="mt-1 text-lg font-bold text-base-content">{@value}</p>
      <p class="text-[10px] uppercase tracking-wide text-base-content/50">{@label}</p>
    </div>
    """
  end

  # Channel Row Component
  attr :channel, :map, required: true

  defp channel_row(assigns) do
    ~H"""
    <div class="flex items-center gap-3 rounded-lg border border-base-300 bg-base-100 p-3">
      <div class={["flex h-8 w-8 items-center justify-center rounded-lg", channel_row_bg(@channel.type)]}>
        <.channel_icon channel={@channel.type} class="h-4 w-4 text-white" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-base-content truncate">{@channel.name}</p>
        <p class="text-xs text-base-content/50 capitalize">{@channel.type}</p>
      </div>
      <.badge variant="soft" color="success" size="xs">Active</.badge>
    </div>
    """
  end

  defp channel_row_bg(:voice), do: "bg-gradient-to-br from-blue-500 to-cyan-600"
  defp channel_row_bg(:email), do: "bg-gradient-to-br from-orange-500 to-rose-600"
  defp channel_row_bg(:chat), do: "bg-gradient-to-br from-teal-500 to-emerald-600"
  defp channel_row_bg(:whatsapp), do: "bg-gradient-to-br from-green-500 to-emerald-600"
  defp channel_row_bg(_), do: "bg-gradient-to-br from-slate-500 to-gray-600"

  # Mount and Event Handlers
  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)

    avatars_by_agent =
      Avatars.latest_avatars_by_agent(socket.assigns.current_scope, agent_ids(agents))

    channels_by_agent = load_channels_by_agent(tenant.id, agents)
    stats_by_agent = load_stats_by_agent(tenant.id, agents)

    # Initial filter/sort state
    default_filters = %{"status" => "", "language" => "", "query" => ""}
    default_sort = %{field: "name", direction: "asc"}

    {:ok,
     socket
     |> assign(:all_agents, agents)
     |> assign(:filtered_agents, agents)
     |> assign(:avatars_by_agent, avatars_by_agent)
     |> assign(:channels_by_agent, channels_by_agent)
     |> assign(:stats_by_agent, stats_by_agent)
     |> assign(:all_agents_count, length(agents))
     |> assign(:filters, default_filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(default_filters, as: :filters))
     |> assign(:sort, default_sort)
     |> assign(:view_mode, "grid")
     |> assign(:sheet_open, false)
     |> assign(:selected_agent, nil)}
  end

  @impl true
  def handle_event("filter", %{"filters" => new_filters}, socket) do
    merged_filters = Map.merge(socket.assigns.filters, new_filters)
    filters_active = filters_active?(merged_filters)

    filtered_agents =
      socket.assigns.all_agents
      |> filter_agents(merged_filters)
      |> sort_agents(socket.assigns.sort, socket.assigns.stats_by_agent)

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> assign(:filters_active, filters_active)
     |> assign(:filter_form, to_form(merged_filters, as: :filters))
     |> assign(:filtered_agents, filtered_agents)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    default_filters = %{"status" => "", "language" => "", "query" => ""}

    sorted_agents = sort_agents(socket.assigns.all_agents, socket.assigns.sort, socket.assigns.stats_by_agent)

    {:noreply,
     socket
     |> assign(:filters, default_filters)
     |> assign(:filters_active, false)
     |> assign(:filter_form, to_form(default_filters, as: :filters))
     |> assign(:filtered_agents, sorted_agents)}
  end

  @impl true
  def handle_event("sort", %{"sort" => field}, socket) do
    current_sort = socket.assigns.sort

    new_sort =
      if current_sort.field == field do
        # Toggle direction
        %{field: field, direction: toggle_direction(current_sort.direction)}
      else
        # New field, default to ascending (or descending for calls/minutes)
        default_dir = if field in ["calls", "minutes"], do: "desc", else: "asc"
        %{field: field, direction: default_dir}
      end

    sorted_agents = sort_agents(socket.assigns.filtered_agents, new_sort, socket.assigns.stats_by_agent)

    {:noreply,
     socket
     |> assign(:sort, new_sort)
     |> assign(:filtered_agents, sorted_agents)}
  end

  @impl true
  def handle_event("set_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("select_agent", %{"id" => agent_id}, socket) do
    agent = Enum.find(socket.assigns.all_agents, &(&1.id == agent_id))

    {:noreply,
     socket
     |> assign(:selected_agent, agent)
     |> assign(:sheet_open, true)}
  end

  @impl true
  def handle_event("close_sheet", _params, socket) do
    {:noreply,
     socket
     |> assign(:sheet_open, false)
     |> assign(:selected_agent, nil)}
  end

  # Filter Logic

  defp filter_agents(agents, filters) do
    agents
    |> filter_by_status(filters["status"])
    |> filter_by_language(filters["language"])
    |> filter_by_query(filters["query"])
  end

  defp filter_by_status(agents, nil), do: agents
  defp filter_by_status(agents, ""), do: agents
  defp filter_by_status(agents, status), do: Enum.filter(agents, &(&1.status == status))

  defp filter_by_language(agents, nil), do: agents
  defp filter_by_language(agents, ""), do: agents
  defp filter_by_language(agents, language), do: Enum.filter(agents, &(&1.language == language))

  defp filter_by_query(agents, nil), do: agents
  defp filter_by_query(agents, ""), do: agents

  defp filter_by_query(agents, query) do
    query_lower = String.downcase(String.trim(query))

    Enum.filter(agents, fn agent ->
      name_match = agent.name && String.contains?(String.downcase(agent.name), query_lower)
      model_match = agent.llm_model && String.contains?(String.downcase(agent.llm_model), query_lower)
      lang_match = agent.language && String.contains?(String.downcase(agent.language), query_lower)
      name_match or model_match or lang_match
    end)
  end

  defp filters_active?(filters) do
    query = filters |> Map.get("query", "") |> to_string() |> String.trim()

    Map.get(filters, "status", "") != "" or
      Map.get(filters, "language", "") != "" or
      query != ""
  end

  # Sort Logic

  defp sort_agents(agents, %{field: field, direction: direction}, stats_by_agent) do
    sorted =
      case field do
        "name" ->
          Enum.sort_by(agents, &(&1.name || ""), :asc)

        "status" ->
          status_order = %{"active" => 0, "draft" => 1, "archived" => 2}
          Enum.sort_by(agents, &Map.get(status_order, &1.status, 3), :asc)

        "language" ->
          Enum.sort_by(agents, &(&1.language || ""), :asc)

        "calls" ->
          Enum.sort_by(agents, fn agent ->
            Map.get(stats_by_agent[agent.id] || %{}, :calls, 0)
          end, :desc)

        "minutes" ->
          Enum.sort_by(agents, fn agent ->
            Map.get(stats_by_agent[agent.id] || %{}, :minutes, 0)
          end, :desc)

        _ ->
          agents
      end

    if direction == "desc" and field not in ["calls", "minutes"] do
      Enum.reverse(sorted)
    else
      if direction == "asc" and field in ["calls", "minutes"] do
        Enum.reverse(sorted)
      else
        sorted
      end
    end
  end

  defp toggle_direction("asc"), do: "desc"
  defp toggle_direction("desc"), do: "asc"
  defp toggle_direction(_), do: "asc"

  # Data Loading Helpers

  defp load_channels_by_agent(_tenant_id, agents) do
    agents
    |> Enum.map(fn agent ->
      channels =
        Agents.list_agent_channels(agent.id)
        |> Enum.filter(& &1.enabled)
        |> Enum.map(& &1.channel)
        |> Enum.reject(&is_nil/1)

      {agent.id, channels}
    end)
    |> Map.new()
  end

  defp load_stats_by_agent(tenant_id, agents) do
    # Get dashboard stats which includes agent leaderboard
    dashboard_stats = CallsDashboard.get_dashboard_stats(tenant_id)
    agent_stats = dashboard_stats.agent_leaderboard.stats

    # Convert to a map by agent_id
    agents
    |> Enum.map(fn agent ->
      stats = Enum.find(agent_stats, &(&1.agent_id == agent.id))

      if stats do
        {agent.id,
         %{
           calls: stats.total_calls,
           minutes: div(stats.total_talk_time, 60),
           completion_rate: stats.completion_rate
         }}
      else
        {agent.id, %{calls: 0, minutes: 0, completion_rate: 0}}
      end
    end)
    |> Map.new()
  end

  # Formatting Helpers

  defp format_duration(seconds) when seconds >= 3600 do
    hours = div(seconds, 3600)
    mins = rem(seconds, 3600) |> div(60)
    "#{hours}h #{mins}m"
  end

  defp format_duration(seconds) when seconds >= 60 do
    mins = div(seconds, 60)
    "#{mins}m"
  end

  defp format_duration(seconds), do: "#{seconds}s"

  defp format_minutes(0), do: "0"
  defp format_minutes(mins) when mins >= 60, do: "#{Float.round(mins / 60, 1)}h"
  defp format_minutes(mins), do: "#{mins}"

  defp format_percent(rate) when rate == 0 or rate == 0.0, do: "—"
  defp format_percent(rate) when is_float(rate), do: "#{Float.round(rate, 0)}%"
  defp format_percent(rate), do: "#{rate}%"

  defp model_short(nil), do: "—"

  defp model_short(model) when is_binary(model) do
    model
    |> String.split("/")
    |> List.last()
    |> String.slice(0..16)
    |> then(fn s -> if String.length(s) > 14, do: String.slice(s, 0..13) <> "…", else: s end)
  end

  defp language_flag("en-IN"), do: "🇮🇳"
  defp language_flag("hi-IN"), do: "🇮🇳"
  defp language_flag("en-US"), do: "🇺🇸"
  defp language_flag("es-US"), do: "🇺🇸"
  defp language_flag("de-DE"), do: "🇩🇪"
  defp language_flag("fr-FR"), do: "🇫🇷"
  defp language_flag("ja-JP"), do: "🇯🇵"
  defp language_flag("pt-BR"), do: "🇧🇷"
  defp language_flag(_), do: "🌐"

  defp language_name("en-IN"), do: "English (India)"
  defp language_name("hi-IN"), do: "Hindi"
  defp language_name("en-US"), do: "English (US)"
  defp language_name("es-US"), do: "Spanish (US)"
  defp language_name("de-DE"), do: "German"
  defp language_name("fr-FR"), do: "French"
  defp language_name("ja-JP"), do: "Japanese"
  defp language_name(lang), do: lang

  # Status Helpers

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:draft), do: "warning"
  defp status_color("draft"), do: "warning"
  defp status_color(:archived), do: "neutral"
  defp status_color("archived"), do: "neutral"
  defp status_color(_), do: "info"

  defp status_label("active"), do: "Active"
  defp status_label("draft"), do: "Draft"
  defp status_label("archived"), do: "Archived"
  defp status_label(status), do: String.capitalize(to_string(status))

  defp status_badge_class("active"),
    do: "bg-emerald-500/90 text-white"

  defp status_badge_class("draft"),
    do: "bg-amber-500/90 text-white"

  defp status_badge_class("archived"),
    do: "bg-base-content/30 text-base-content"

  defp status_badge_class(_),
    do: "bg-base-content/20 text-base-content"

  defp status_dot_class("active"), do: "bg-white animate-pulse"
  defp status_dot_class("draft"), do: "bg-white/80"
  defp status_dot_class(_), do: "bg-white/50"

  defp status_ring_bg("active"), do: "bg-emerald-500"
  defp status_ring_bg("draft"), do: "bg-amber-500"
  defp status_ring_bg("archived"), do: "bg-base-400"
  defp status_ring_bg(_), do: "bg-base-400"

  defp status_icon("active"), do: "hero-check-mini"
  defp status_icon("draft"), do: "hero-pencil-mini"
  defp status_icon("archived"), do: "hero-archive-box-mini"
  defp status_icon(_), do: "hero-question-mark-circle-mini"

  # Agent Helpers

  defp agent_ids(agents), do: Enum.map(agents, & &1.id)

  defp initials(nil), do: "?"

  defp initials(name) when is_binary(name) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp avatar_ready?(nil), do: false

  defp avatar_ready?(%{status: :ready, output_url: url}) when is_binary(url), do: true
  defp avatar_ready?(_), do: false

  # Filter & Sort Options

  defp status_options do
    [
      {"Active", "active"},
      {"Draft", "draft"},
      {"Archived", "archived"}
    ]
  end

  defp language_options(agents) do
    agents
    |> Enum.map(& &1.language)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
    |> Enum.map(fn lang -> {language_name(lang), lang} end)
  end

  defp sort_options do
    [
      {"Name", "name"},
      {"Status", "status"},
      {"Language", "language"},
      {"Most Calls", "calls"},
      {"Most Talk Time", "minutes"}
    ]
  end

  # Filter Labels

  defp status_filter_label(filters) do
    case Map.get(filters, "status", "") do
      "" -> "Status"
      status -> status_label(status)
    end
  end

  defp language_filter_label(filters) do
    case Map.get(filters, "language", "") do
      "" -> "Language"
      lang -> "#{language_flag(lang)} #{lang}"
    end
  end

  defp sort_label(%{field: field, direction: direction}) do
    label =
      case field do
        "name" -> "Name"
        "status" -> "Status"
        "language" -> "Language"
        "calls" -> "Calls"
        "minutes" -> "Talk Time"
        _ -> "Sort"
      end

    arrow = if direction == "asc", do: "↑", else: "↓"
    "#{label} #{arrow}"
  end

  defp status_dot_for_filter("active"), do: "bg-emerald-500"
  defp status_dot_for_filter("draft"), do: "bg-amber-500"
  defp status_dot_for_filter("archived"), do: "bg-base-400"
  defp status_dot_for_filter(_), do: "bg-base-300"
end
