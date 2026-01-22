defmodule SwatiWeb.AgentsLive.Form do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Agents.Agent
  alias Swati.Avatars
  alias Swati.Channels
  alias Swati.Integrations
  alias Swati.Webhooks
  alias SwatiWeb.Formatting

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Character Sheet Layout -->
      <div class="character-sheet">
        <!-- Top Bar: Title + Actions -->
        <header class="character-sheet-header flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <.link
              navigate={~p"/agents"}
              class="text-base-content/50 hover:text-base-content transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-5" />
            </.link>
            <div>
              <h1 class="text-xl font-semibold text-base-content">{@page_title}</h1>
              <p class="text-xs text-base-content/50">Character configuration</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <.button :if={@live_action == :edit} phx-click="publish" variant="soft" size="sm">
              <.icon name="hero-rocket-launch" class="size-4 mr-1.5" /> Publish
            </.button>
          </div>
        </header>

        <.form for={@form} id="agent-form" phx-change="validate" phx-submit="save">
          <div class="character-sheet-layout grid gap-6 lg:grid-cols-[320px_1fr] xl:grid-cols-[360px_1fr]">
            <!-- LEFT PANEL: Agent Identity & Stats -->
            <aside class="character-portrait-panel space-y-4">
              <!-- Portrait Card - Hero Treatment -->
              <div class="portrait-card rounded-2xl border border-base-300 bg-base-100 overflow-hidden shadow-xl shadow-base-300/50">
                <!-- Dramatic Avatar Section -->
                <div class="portrait-frame relative">
                  <!-- Layered background for depth -->
                  <div class="absolute inset-0 bg-gradient-to-b from-primary/5 via-base-200/80 to-base-100">
                  </div>
                  <div class="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-primary/10 via-transparent to-transparent">
                  </div>
                  
    <!-- Content -->
                  <div class="relative px-6 pt-8 pb-5">
                    <!-- Avatar with dramatic framing -->
                    <div class="portrait-avatar mx-auto relative">
                      <!-- Outer glow ring -->
                      <div class={[
                        "absolute -inset-2 rounded-3xl opacity-60 blur-sm",
                        status_glow_color(@form[:status].value)
                      ]}>
                      </div>
                      
    <!-- Avatar container -->
                      <div class="relative size-32 mx-auto overflow-hidden rounded-2xl border-2 border-white/80 bg-base-200 shadow-2xl ring-1 ring-base-300/50">
                        <%= if @live_action == :edit and avatar_ready?(@avatar) do %>
                          <img
                            class="size-full object-cover"
                            src={@avatar.output_url}
                            alt=""
                            loading="lazy"
                          />
                        <% else %>
                          <div class="flex size-full items-center justify-center bg-gradient-to-br from-base-200 to-base-300">
                            <span class="text-3xl font-bold text-base-content/30">
                              {initials(@agent.name || "?")}
                            </span>
                          </div>
                        <% end %>
                      </div>
                      
    <!-- Status badge - more prominent -->
                      <div class={[
                        "absolute -bottom-1.5 -right-1.5 size-8 rounded-xl border-2 border-white flex items-center justify-center shadow-lg",
                        status_ring_color(@form[:status].value)
                      ]}>
                        <.icon name={status_icon(@form[:status].value)} class="size-4 text-white" />
                      </div>
                    </div>
                    
    <!-- Generate avatar button -->
                    <div :if={@live_action == :edit} class="mt-4 text-center">
                      <button
                        type="button"
                        phx-click="generate_avatar"
                        class="text-xs text-base-content/60 hover:text-primary transition-colors inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-base-100/80 hover:bg-base-100 border border-base-300/50"
                      >
                        <.icon name="hero-sparkles" class="size-3.5" />
                        {if avatar_ready?(@avatar), do: "Regenerate", else: "Generate avatar"}
                      </button>
                    </div>
                  </div>
                </div>
                
    <!-- Name Section - More prominent -->
                <div class="px-5 pb-2 -mt-1">
                  <.input
                    field={@form[:name]}
                    placeholder="Agent name"
                    class="text-center text-xl font-bold border-0 bg-transparent focus:bg-base-200/50 rounded-lg tracking-tight"
                    required
                  />
                </div>
                
    <!-- Key Stats - Visual hierarchy improved -->
                <div class="mx-4 mb-4 rounded-xl bg-gradient-to-r from-base-200/80 via-base-200/60 to-base-200/80 p-3 border border-base-300/30">
                  <div class="grid grid-cols-3 divide-x divide-base-300/50">
                    <.hero_stat
                      label="Status"
                      value={String.capitalize(@form[:status].value || "draft")}
                      color={status_chip_color(@form[:status].value)}
                    />
                    <.hero_stat
                      label="Language"
                      value={language_short(@form[:language].value)}
                      color="info"
                    />
                    <.hero_stat
                      label="Model"
                      value={model_short(@form[:llm_model].value)}
                      color="primary"
                    />
                  </div>
                </div>
              </div>
              
    <!-- Attributes Panel -->
              <.collapsible_section
                id="attributes"
                title="Attributes"
                icon="hero-adjustments-horizontal"
                open={@expanded_sections["attributes"]}
              >
                <div class="space-y-3">
                  <.select field={@form[:status]} label="Status" options={@status_options} size="sm" />
                  <.select
                    field={@form[:language]}
                    label="Language"
                    options={@language_options}
                    size="sm"
                  />
                  <.input field={@form[:llm_model]} label="LLM Model" size="sm" />
                </div>
              </.collapsible_section>
              
    <!-- Voice & Personality Panel -->
              <.collapsible_section
                id="voice"
                title="Voice & Personality"
                icon="hero-speaker-wave"
                open={@expanded_sections["voice"]}
              >
                <div class="space-y-3">
                  <.input field={@form[:voice_provider]} label="Voice provider" size="sm" />
                  <.select
                    field={@form[:voice_name]}
                    label="Voice"
                    options={@voice_options}
                    size="sm"
                  />
                  <.input field={@form[:llm_provider]} label="LLM provider" size="sm" />
                </div>
              </.collapsible_section>
            </aside>
            
    <!-- RIGHT PANEL: Configuration Sections -->
            <main class="character-config-panel space-y-4">
              <!-- Instructions Section -->
              <.collapsible_section
                id="instructions"
                title="Instructions"
                subtitle="Define the agent's behavior and knowledge"
                icon="hero-document-text"
                open={@expanded_sections["instructions"]}
                badge_text={instructions_word_count(@form[:instructions].value)}
              >
                <.textarea
                  field={@form[:instructions]}
                  placeholder="You are a helpful assistant..."
                  rows={12}
                  class="font-mono text-sm"
                />
              </.collapsible_section>
              
    <!-- Escalation Section -->
              <.collapsible_section
                id="escalation"
                title="Escalation Policy"
                subtitle="When and how to hand off to humans"
                icon="hero-arrow-up-on-square"
                open={@expanded_sections["escalation"]}
                badge_text={if @escalation_enabled, do: "Active", else: "Off"}
                badge_color={if @escalation_enabled, do: "success", else: "info"}
              >
                <div class="space-y-4">
                  <div class="flex items-center justify-between p-3 rounded-xl bg-base-200/50 border border-base-200">
                    <div>
                      <p class="text-sm font-medium text-base-content">Enable escalation</p>
                      <p class="text-xs text-base-content/60">
                        Allow agent to transfer to human support
                      </p>
                    </div>
                    <.switch
                      name="agent[escalation_enabled]"
                      checked={@escalation_enabled}
                    />
                  </div>
                  <div :if={@escalation_enabled}>
                    <.input
                      name="agent[escalation_note]"
                      label="Escalation message"
                      value={@escalation_note}
                      placeholder="Let me connect you with a human agent..."
                      size="sm"
                    />
                  </div>
                </div>
              </.collapsible_section>
              
    <!-- Tool Policy Section (edit mode) -->
              <.collapsible_section
                :if={@live_action == :edit}
                id="tools"
                title="Tool Policy"
                subtitle="Configure allowed and denied tools"
                icon="hero-wrench-screwdriver"
                open={@expanded_sections["tools"]}
                badge_text={"#{effective_tools_count(@effective_tools)} enabled"}
              >
                <.tool_policy_panel
                  tool_allowlist={@tool_allowlist}
                  tool_denylist={@tool_denylist}
                  max_calls_per_turn={@max_calls_per_turn}
                  effective_tools={@effective_tools}
                />
              </.collapsible_section>
              
    <!-- Channels Section (edit mode) -->
              <.collapsible_section
                :if={@live_action == :edit}
                id="channels"
                title="Channels"
                subtitle="Enable communication channels"
                icon="hero-signal"
                open={@expanded_sections["channels"]}
                badge_text={"#{length(@channels)} available"}
              >
                <.channels_panel
                  channels={@channels}
                  channel_states={@channel_states}
                  channel_health={@channel_health}
                  search_query={@channel_search}
                />
              </.collapsible_section>
              
    <!-- Integrations Section (edit mode) -->
              <.collapsible_section
                :if={@live_action == :edit}
                id="integrations"
                title="Integrations"
                subtitle="MCP server connections"
                icon="hero-cube"
                open={@expanded_sections["integrations"]}
                badge_text={"#{length(@integrations)} configured"}
              >
                <.integrations_panel
                  integrations={@integrations}
                  integration_states={@integration_states}
                />
              </.collapsible_section>
              
    <!-- Webhooks Section (edit mode) -->
              <.collapsible_section
                :if={@live_action == :edit}
                id="webhooks"
                title="Webhooks"
                subtitle="HTTP endpoint tools"
                icon="hero-bolt"
                open={@expanded_sections["webhooks"]}
                badge_text={"#{length(@webhooks)} configured"}
              >
                <.webhooks_panel
                  webhooks={@webhooks}
                  webhook_states={@webhook_states}
                />
              </.collapsible_section>
              
    <!-- Save Button -->
              <div class="flex justify-end pt-2">
                <.button type="submit" variant="solid" class="px-6">
                  <.icon name="hero-check" class="size-4 mr-1.5" /> Save changes
                </.button>
              </div>
            </main>
          </div>
        </.form>
      </div>
      
    <!-- Channel Scope Sheet -->
      <.sheet
        :if={@live_action == :edit}
        id="channel-scope-sheet"
        placement="right"
        class="w-full max-w-lg"
        open={@scope_sheet_open}
        on_close={JS.push("close_scope_sheet")}
      >
        <div :if={@scope_channel} class="space-y-6">
          <header class="space-y-1">
            <div class="flex items-center gap-3">
              <div class={[
                "size-10 flex items-center justify-center rounded-xl",
                channel_type_gradient(@scope_channel.type)
              ]}>
                <.icon name={channel_type_icon(@scope_channel.type)} class="size-5 text-white" />
              </div>
              <div>
                <h3 class="text-lg font-semibold text-foreground">{@scope_channel.name}</h3>
                <p class="text-sm text-foreground-soft">{@scope_channel.key}</p>
              </div>
            </div>
          </header>
          
    <!-- Health Summary -->
          <div class="grid grid-cols-3 gap-3">
            <div class="scope-stat rounded-xl border border-base-300 bg-base-200/30 p-3 text-center">
              <p class="text-2xl font-bold text-base-content">{@scope_health.endpoint_count || 0}</p>
              <p class="text-xs text-base-content/60">Endpoints</p>
            </div>
            <div class="scope-stat rounded-xl border border-base-300 bg-base-200/30 p-3 text-center">
              <p class="text-2xl font-bold text-success">{@scope_health.active_count || 0}</p>
              <p class="text-xs text-base-content/60">Active</p>
            </div>
            <div class="scope-stat rounded-xl border border-base-300 bg-base-200/30 p-3 text-center">
              <p class="text-2xl font-bold text-warning">{@scope_health.error_count || 0}</p>
              <p class="text-xs text-base-content/60">Issues</p>
            </div>
          </div>
          
    <!-- Scope Controls -->
          <div class="space-y-4">
            <h4 class="text-sm font-semibold text-base-content">Endpoint Access</h4>
            <div class="space-y-2">
              <label class={[
                "scope-radio flex items-center gap-3 rounded-xl border p-4 cursor-pointer transition-all",
                @scope_mode == "all" && "border-primary bg-primary/5 ring-1 ring-primary/20",
                @scope_mode != "all" && "border-base-300 hover:border-base-400"
              ]}>
                <input
                  type="radio"
                  name="scope_mode"
                  value="all"
                  checked={@scope_mode == "all"}
                  phx-click="set_scope_mode"
                  phx-value-mode="all"
                  class="radio radio-primary radio-sm"
                />
                <div>
                  <p class="font-medium text-base-content">All endpoints</p>
                  <p class="text-xs text-base-content/60">
                    Agent can access all endpoints on this channel
                  </p>
                </div>
              </label>

              <label class={[
                "scope-radio flex items-center gap-3 rounded-xl border p-4 cursor-pointer transition-all",
                @scope_mode == "selected" && "border-primary bg-primary/5 ring-1 ring-primary/20",
                @scope_mode != "selected" && "border-base-300 hover:border-base-400"
              ]}>
                <input
                  type="radio"
                  name="scope_mode"
                  value="selected"
                  checked={@scope_mode == "selected"}
                  phx-click="set_scope_mode"
                  phx-value-mode="selected"
                  class="radio radio-primary radio-sm"
                />
                <div>
                  <p class="font-medium text-base-content">Selected endpoints only</p>
                  <p class="text-xs text-base-content/60">Restrict agent to specific endpoints</p>
                </div>
              </label>
            </div>
          </div>
          
    <!-- Endpoint Selection (when mode=selected) -->
          <div :if={@scope_mode == "selected"} class="space-y-3">
            <h4 class="text-sm font-semibold text-base-content">Select Endpoints</h4>
            <div class="space-y-2 max-h-64 overflow-y-auto pr-1">
              <label
                :for={endpoint <- @scope_endpoints}
                class={[
                  "endpoint-row flex items-center gap-3 rounded-xl border p-3 cursor-pointer transition-all",
                  endpoint.id in @scope_selected_ids && "border-primary/50 bg-primary/5",
                  endpoint.id not in @scope_selected_ids && "border-base-300 hover:border-base-400"
                ]}
              >
                <input
                  type="checkbox"
                  name="selected_endpoints[]"
                  value={endpoint.id}
                  checked={endpoint.id in @scope_selected_ids}
                  phx-click="toggle_scope_endpoint"
                  phx-value-endpoint_id={endpoint.id}
                  class="checkbox checkbox-primary checkbox-sm"
                />
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-base-content truncate">{endpoint.address}</p>
                  <p class="text-xs text-base-content/60">
                    {endpoint.display_name || "No display name"}
                  </p>
                </div>
                <.badge
                  size="xs"
                  variant="soft"
                  color={endpoint_connection_color(@scope_connections, endpoint.id)}
                >
                  {endpoint_connection_label(@scope_connections, endpoint.id)}
                </.badge>
              </label>
              <p :if={@scope_endpoints == []} class="text-sm text-base-content/60 text-center py-4">
                No endpoints found for this channel.
              </p>
            </div>
          </div>
          
    <!-- Tools Preview -->
          <div class="space-y-3">
            <h4 class="text-sm font-semibold text-base-content">Available Tools</h4>
            <div class="rounded-xl border border-base-300 bg-base-200/30 p-4">
              <div class="flex flex-wrap gap-2">
                <.badge
                  :for={tool <- channel_tools(@scope_channel)}
                  size="sm"
                  variant="soft"
                  color="info"
                >
                  {tool}
                </.badge>
                <p :if={channel_tools(@scope_channel) == []} class="text-sm text-base-content/60">
                  No tools defined for this channel.
                </p>
              </div>
            </div>
          </div>
          
    <!-- Actions -->
          <div class="flex items-center justify-between pt-4 border-t border-base-300">
            <.link navigate={~p"/channels"} class="text-sm text-primary hover:underline">
              Manage connections
            </.link>
            <div class="flex items-center gap-2">
              <.button variant="ghost" phx-click="close_scope_sheet">Cancel</.button>
              <.button variant="solid" phx-click="save_scope">Save scope</.button>
            </div>
          </div>
        </div>
      </.sheet>
    </Layouts.app>
    """
  end

  # Tool Policy Panel Component
  attr :tool_allowlist, :string, required: true
  attr :tool_denylist, :string, required: true
  attr :max_calls_per_turn, :integer, required: true
  attr :effective_tools, :list, required: true

  defp tool_policy_panel(assigns) do
    ~H"""
    <div class="grid gap-6 lg:grid-cols-2">
      <!-- Policy Configuration -->
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-semibold">Tool Policy</h3>
          <.badge variant="soft" color="info" size="xs">
            Gates final allowlist
          </.badge>
        </div>
        <div class="space-y-4">
          <.textarea
            name="agent[tool_allowlist]"
            label="Allowed tools"
            value={@tool_allowlist}
            rows={5}
          />
          <.textarea name="agent[tool_denylist]" label="Denied tools" value={@tool_denylist} rows={5} />
          <.input
            name="agent[max_calls_per_turn]"
            label="Max calls per turn"
            type="number"
            value={@max_calls_per_turn}
          />
        </div>
      </div>
      
    <!-- Effective Tools Preview -->
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-semibold">Effective Tools Preview</h3>
          <span class="text-xs text-base-content/60">What this agent can actually do</span>
        </div>
        <div class="effective-tools-preview rounded-xl border border-base-300 bg-gradient-to-br from-base-200/50 to-base-100 p-4 min-h-[280px]">
          <div
            :if={@effective_tools == []}
            class="flex flex-col items-center justify-center h-full text-center py-8"
          >
            <div class="size-12 rounded-full bg-base-300/50 flex items-center justify-center mb-3">
              <.icon name="hero-wrench-screwdriver" class="size-6 text-base-content/40" />
            </div>
            <p class="text-sm text-base-content/60">No tools enabled yet.</p>
            <p class="text-xs text-base-content/40 mt-1">
              Enable channels, integrations, or webhooks to add tools.
            </p>
          </div>
          <div :if={@effective_tools != []} class="space-y-4">
            <div :for={{source, tools, grants} <- @effective_tools} class="space-y-2">
              <div class="flex items-center gap-2">
                <.icon name={source_icon(source)} class="size-4 text-base-content/60" />
                <h4 class="text-xs font-semibold uppercase tracking-wider text-base-content/60">
                  {source_label(source)}
                </h4>
                <span class="text-xs text-base-content/40">
                  {length(tools)} unique
                  <span :if={grants != length(tools)}> ·         {grants} grants</span>
                </span>
              </div>
              <div class="flex flex-wrap gap-1.5">
                <.popover
                  :for={{tool, sources} <- tools}
                  open_on_hover
                  placement="right"
                  class="min-w-[140px]"
                >
                  <span class="effective-tool-chip inline-flex items-center gap-1 px-2 py-1 text-xs font-medium rounded-lg bg-base-300/50 text-base-content/80 border border-base-300/50 cursor-default hover:bg-base-300 hover:border-base-400 transition-colors">
                    {tool}
                    <span
                      :if={length(sources) > 1}
                      class="ml-0.5 text-[10px] text-base-content/50 font-normal"
                    >
                      ({length(sources)})
                    </span>
                  </span>
                  <:content>
                    <p class="text-xs font-semibold text-base-content/60 uppercase tracking-wider mb-2">
                      Provided by
                    </p>
                    <div class="flex flex-col gap-1">
                      <span
                        :for={src <- sources}
                        class="inline-flex items-center gap-2 text-sm text-base-content"
                      >
                        <span class="size-1.5 rounded-full bg-success"></span>
                        {src}
                      </span>
                    </div>
                  </:content>
                </.popover>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Channels Panel Component
  attr :channels, :list, required: true
  attr :channel_states, :map, required: true
  attr :channel_health, :map, required: true
  attr :search_query, :string, required: true

  defp channels_panel(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Header with search and bulk actions -->
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex-1 max-w-xs">
          <.input
            type="search"
            name="channel_search"
            placeholder="Search channels..."
            value={@search_query}
            phx-change="search_channels"
            phx-debounce="150"
          />
        </div>
        <div class="flex items-center gap-1.5">
          <.button
            type="button"
            variant="soft"
            size="sm"
            phx-click="enable_all_channels"
            class="text-xs"
          >
            Enable all
          </.button>
          <.button
            type="button"
            variant="soft"
            size="sm"
            phx-click="disable_all_channels"
            class="text-xs"
          >
            Disable all
          </.button>
          <.button
            type="button"
            variant="solid"
            color="primary"
            size="sm"
            phx-click="enable_connected_channels"
            class="text-xs"
          >
            Enable connected only
          </.button>
        </div>
      </div>
      
    <!-- Channel List -->
      <.form
        for={%{}}
        id="agent-channels"
        phx-change="toggle_channel"
        class="space-y-0"
      >
        <div
          :for={
            channel <-
              sort_channels(
                filter_channels(@channels, @search_query),
                @channel_states,
                @channel_health
              )
          }
          class="channel-row group py-3 first:pt-0 last:pb-0 transition-colors hover:bg-base-200/30 border-b border-base-300/60 last:border-0"
        >
          <div class="flex items-start gap-3">
            <.icon
              name={channel_type_icon(channel.type)}
              class="size-4 text-base-content/40 shrink-0 mt-0.5"
            />
            
    <!-- Channel Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <h4 class="font-semibold text-base-content truncate">{channel.name}</h4>
                <!-- Combined state badge: Enabled + Connection status -->
                <.badge
                  size="xs"
                  variant="soft"
                  color={channel_combined_color(@channel_states, @channel_health, channel.id)}
                >
                  {channel_combined_label(@channel_states, @channel_health, channel.id)}
                </.badge>
              </div>
              <div class="flex items-center gap-2 mt-1.5 text-xs text-base-content/60">
                <span class="inline-flex items-center gap-1">
                  <span class="text-base-content/40">Type:</span>
                  <span class="capitalize">{format_channel_type(channel.type)}</span>
                </span>
                <span class="text-base-content/30">·</span>
                <!-- Tools with Fluxon popover -->
                <.popover open_on_hover placement="right" class="w-[340px]">
                  <span class="inline-flex items-center gap-1 cursor-default hover:text-base-content transition-colors">
                    <span class="text-base-content/40">Tools:</span>
                    <span class="font-medium">{length(channel_tools(channel))}</span>
                    <.icon
                      name="hero-information-circle"
                      class="size-3.5 text-base-content/30 hover:text-primary transition-colors"
                    />
                  </span>
                  <:content>
                    <div class="space-y-3">
                      <div class="flex items-center justify-between">
                        <p class="text-xs font-semibold text-base-content">Channel Tools</p>
                        <span class="text-xs text-base-content/50">
                          {length(channel_tools(channel))} available
                        </span>
                      </div>
                      <div class="flex flex-wrap gap-1.5">
                        <.badge
                          :for={tool <- channel_tools(channel)}
                          size="xs"
                          variant="soft"
                          color="info"
                        >
                          {tool}
                        </.badge>
                        <span
                          :if={channel_tools(channel) == []}
                          class="text-sm text-base-content/50 italic"
                        >
                          No tools configured
                        </span>
                      </div>
                      <p class="text-xs text-base-content/50 pt-2 border-t border-base-200">
                        <span class="text-success font-medium">Tip:</span>
                        Click "Scope" to restrict endpoint access.
                      </p>
                    </div>
                  </:content>
                </.popover>
              </div>
            </div>
            
    <!-- Actions -->
            <div class="flex items-center gap-2 shrink-0">
              <button
                type="button"
                phx-click="open_scope_sheet"
                phx-value-channel_id={channel.id}
                class="text-xs text-base-content/40 hover:text-primary transition-colors opacity-0 group-hover:opacity-100"
              >
                Scope
              </button>
              <.switch
                name={"channels[#{channel.id}]"}
                checked={Map.get(@channel_states, channel.id, false)}
              />
            </div>
          </div>
        </div>

        <p
          :if={filter_channels(@channels, @search_query) == []}
          class="text-center text-sm text-base-content/60 py-8"
        >
          {if @search_query != "",
            do: "No channels match your search.",
            else: "No channels configured yet."}
        </p>
      </.form>
    </div>
    """
  end

  # Integrations Panel Component
  attr :integrations, :list, required: true
  attr :integration_states, :map, required: true

  defp integrations_panel(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-base-content/70">
          Toggle which MCP integrations are available to this agent.
        </p>
        <.link navigate={~p"/agent-data"} class="text-sm text-primary hover:underline">
          Manage integrations
        </.link>
      </div>

      <.form
        for={%{}}
        id="agent-integrations"
        phx-change="toggle_integration"
        class="space-y-0"
      >
        <div
          :for={integration <- @integrations}
          class="integration-row group py-3 first:pt-0 last:pb-0 transition-colors hover:bg-base-200/30 border-b border-base-300/60 last:border-0"
        >
          <div class="flex items-start gap-3">
            <.icon name="hero-cube" class="size-4 text-base-content/40 shrink-0 mt-0.5" />
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <h4 class="text-sm font-medium text-base-content truncate">{integration.name}</h4>
                <span class="text-xs text-base-content/40">
                  {length(integration.allowed_tools || [])} tools
                </span>
              </div>
              <div class="flex items-center gap-2 mt-0.5 text-xs text-base-content/50">
                <span :if={integration.last_tested_at}>
                  Tested {format_relative_time(integration.last_tested_at)}
                </span>
                <span :if={integration.last_test_status == "success"} class="text-success/70">
                  · Healthy
                </span>
                <span
                  :if={integration.last_test_status && integration.last_test_status != "success"}
                  class="text-warning/70"
                >
                  · {integration.last_test_status}
                </span>
              </div>
            </div>
            <div class="flex items-center gap-2 shrink-0">
              <.switch
                name={"integrations[#{integration.id}]"}
                checked={Map.get(@integration_states, integration.id, true)}
              />
            </div>
          </div>
        </div>

        <p :if={@integrations == []} class="text-center text-sm text-base-content/50 py-6">
          No integrations configured yet.
          <.link navigate={~p"/agent-data"} class="text-primary hover:underline ml-1">
            Add your first integration
          </.link>
        </p>
      </.form>
    </div>
    """
  end

  # Webhooks Panel Component
  attr :webhooks, :list, required: true
  attr :webhook_states, :map, required: true

  defp webhooks_panel(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <p class="text-sm text-base-content/70">
          Toggle which webhook tools are available to this agent.
        </p>
        <.link navigate={~p"/agent-data"} class="text-sm text-primary hover:underline">
          Manage webhooks
        </.link>
      </div>

      <.form
        for={%{}}
        id="agent-webhooks"
        phx-change="toggle_webhook"
        class="space-y-0"
      >
        <div
          :for={webhook <- @webhooks}
          class="webhook-row group py-3 first:pt-0 last:pb-0 transition-colors hover:bg-base-200/30 border-b border-base-300/60 last:border-0"
        >
          <div class="flex items-start gap-3">
            <.icon name="hero-bolt" class="size-4 text-base-content/40 shrink-0 mt-0.5" />
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <h4 class="text-sm font-medium text-base-content truncate">{webhook.name}</h4>
                <span class="text-[10px] font-mono text-base-content/40 uppercase">
                  {webhook.http_method |> to_string() |> String.upcase()}
                </span>
              </div>
              <p class="text-xs text-base-content/50 truncate mt-0.5">
                <code class="text-base-content/60">{webhook.tool_name}</code>
              </p>
            </div>
            <.switch
              name={"webhooks[#{webhook.id}]"}
              checked={Map.get(@webhook_states, webhook.id, true)}
            />
          </div>
        </div>

        <p :if={@webhooks == []} class="text-center text-sm text-base-content/50 py-6">
          No webhooks configured.
          <.link navigate={~p"/agent-data"} class="text-primary hover:underline ml-1">
            Add one
          </.link>
        </p>
      </.form>
    </div>
    """
  end

  # Stat Chip Component - compact inline stat display
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, default: "info"

  defp stat_chip(assigns) do
    ~H"""
    <div class="stat-chip flex items-center gap-1.5">
      <div class={[
        "size-5 flex items-center justify-center rounded",
        stat_chip_bg(@color)
      ]}>
        <.icon name={@icon} class="size-3 text-base-content/60" />
      </div>
      <div class="flex flex-col">
        <span class="text-[10px] text-base-content/40 uppercase tracking-wider leading-none">
          {@label}
        </span>
        <span class="text-xs font-medium text-base-content/80 leading-tight">{@value}</span>
      </div>
    </div>
    """
  end

  defp stat_chip_bg("success"), do: "bg-success/10"
  defp stat_chip_bg("warning"), do: "bg-warning/10"
  defp stat_chip_bg("danger"), do: "bg-error/10"
  defp stat_chip_bg("info"), do: "bg-info/10"
  defp stat_chip_bg("primary"), do: "bg-primary/10"
  defp stat_chip_bg(_), do: "bg-base-200"

  # Hero Stat Component - prominent stat display for portrait card
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, default: "info"

  defp hero_stat(assigns) do
    ~H"""
    <div class="hero-stat flex flex-col items-center px-2 py-1">
      <span class={[
        "text-sm font-bold tracking-tight",
        hero_stat_color(@color)
      ]}>
        {@value}
      </span>
      <span class="text-[10px] text-base-content/50 uppercase tracking-wider mt-0.5">
        {@label}
      </span>
    </div>
    """
  end

  defp hero_stat_color("success"), do: "text-success"
  defp hero_stat_color("warning"), do: "text-warning"
  defp hero_stat_color("danger"), do: "text-error"
  defp hero_stat_color("info"), do: "text-info"
  defp hero_stat_color("primary"), do: "text-primary"
  defp hero_stat_color(_), do: "text-base-content"

  # Equipment Slot Component - game-style slot for tools/channels
  attr :icon, :string, required: true
  attr :count, :integer, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :on_click, :string, required: true
  attr :tab, :string, required: true

  defp equipment_slot(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={@on_click}
      phx-value-tab={@tab}
      class={[
        "equipment-slot flex flex-col items-center gap-1 p-2 rounded-xl transition-all",
        "hover:bg-base-200/50 focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/50",
        @active && "bg-primary/5 ring-1 ring-primary/20",
        !@active && "bg-base-200/30"
      ]}
    >
      <div class={[
        "size-8 flex items-center justify-center rounded-lg",
        @active && "bg-primary/10 text-primary",
        !@active && "bg-base-300/50 text-base-content/50"
      ]}>
        <.icon name={@icon} class="size-4" />
      </div>
      <span class="text-[10px] text-base-content/50">{@label}</span>
      <span class={[
        "text-sm font-bold",
        @active && "text-primary",
        !@active && "text-base-content/70"
      ]}>
        {@count}
      </span>
    </button>
    """
  end

  # Collapsible Section Component
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :icon, :string, required: true
  attr :open, :boolean, default: true
  attr :badge_text, :string, default: nil
  attr :badge_color, :string, default: "info"
  slot :inner_block, required: true

  defp collapsible_section(assigns) do
    ~H"""
    <section class="collapsible-section rounded-2xl border border-base-300 bg-base-100 overflow-hidden">
      <header
        class="section-header px-5 py-4 cursor-pointer hover:bg-base-200/30 transition-colors"
        phx-click="toggle_section"
        phx-value-section={@id}
      >
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="size-8 flex items-center justify-center rounded-lg bg-base-200/50 text-base-content/60">
              <.icon name={@icon} class="size-4" />
            </div>
            <div>
              <h3 class="text-sm font-semibold text-base-content">{@title}</h3>
              <p :if={@subtitle} class="text-xs text-base-content/50">{@subtitle}</p>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <.badge :if={@badge_text} variant="soft" color={@badge_color} size="xs">
              {@badge_text}
            </.badge>
            <.icon
              name={if @open, do: "hero-chevron-up", else: "hero-chevron-down"}
              class="size-4 text-base-content/40"
            />
          </div>
        </div>
      </header>
      <div
        :if={@open}
        class="section-content px-5 pb-5 animate-in fade-in slide-in-from-top-1 duration-150"
      >
        {render_slot(@inner_block)}
      </div>
    </section>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status_options, status_options())
     |> assign(:language_options, language_options())
     |> assign(:voice_options, voice_options())
     |> assign(:channels, [])
     |> assign(:channel_states, %{})
     |> assign(:channel_health, %{})
     |> assign(:channel_search, "")
     |> assign(:integrations, [])
     |> assign(:integration_states, %{})
     |> assign(:webhooks, [])
     |> assign(:webhook_states, %{})
     |> assign(:active_tab, "channels")
     |> assign(:effective_tools, [])
     |> assign(:scope_sheet_open, false)
     |> assign(:scope_channel, nil)
     |> assign(:scope_health, %{})
     |> assign(:scope_endpoints, [])
     |> assign(:scope_connections, %{})
     |> assign(:scope_mode, "all")
     |> assign(:scope_selected_ids, [])
     |> assign(:expanded_sections, %{
       "attributes" => false,
       "voice" => false,
       "instructions" => true,
       "escalation" => false,
       "tools" => false,
       "channels" => true,
       "integrations" => false,
       "webhooks" => false
     })}
  end

  @impl true
  def handle_params(params, _url, socket) do
    case socket.assigns.live_action do
      :new ->
        agent = %Agent{
          status: "draft",
          llm_model: Agent.default_llm_model(),
          instructions: Agent.default_instructions(),
          tool_policy: Agent.default_tool_policy()
        }

        {:noreply,
         socket
         |> assign(:page_title, "New agent")
         |> assign_agent(agent)}

      :edit ->
        tenant_id = socket.assigns.current_scope.tenant.id
        agent = Agents.get_agent!(tenant_id, params["id"])
        channels = Channels.list_channels(tenant_id)
        integrations = Integrations.list_integrations(tenant_id)
        webhooks = Webhooks.list_webhooks(tenant_id)
        channel_states = channel_states(agent, channels)
        channel_health = Channels.channel_health_map(tenant_id)
        integration_states = integration_states(agent, integrations)
        webhook_states = webhook_states(agent, webhooks)

        effective_tools =
          compute_effective_tools(
            channels,
            channel_states,
            integrations,
            integration_states,
            webhooks,
            webhook_states,
            agent.tool_policy
          )

        {:noreply,
         socket
         |> assign(:page_title, "Edit agent")
         |> assign(:channels, channels)
         |> assign(:channel_states, channel_states)
         |> assign(:channel_health, channel_health)
         |> assign(:integrations, integrations)
         |> assign(:integration_states, integration_states)
         |> assign(:webhooks, webhooks)
         |> assign(:webhook_states, webhook_states)
         |> assign(:effective_tools, effective_tools)
         |> assign_agent(agent)}
    end
  end

  @impl true
  def handle_event("validate", %{"agent" => params}, socket) do
    attrs = build_agent_attrs(params, socket.assigns.agent)
    changeset = Agent.changeset(socket.assigns.agent, attrs) |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset, attrs)}
  end

  @impl true
  def handle_event("save", %{"agent" => params}, socket) do
    attrs = build_agent_attrs(params, socket.assigns.agent)

    case socket.assigns.live_action do
      :new ->
        case Agents.create_agent(
               socket.assigns.current_scope.tenant.id,
               attrs,
               socket.assigns.current_scope.user
             ) do
          {:ok, _agent} ->
            {:noreply,
             socket
             |> put_flash(:info, "Agent created.")
             |> push_navigate(to: ~p"/agents")}

          {:error, changeset} ->
            {:noreply, assign_form(socket, changeset, attrs)}
        end

      :edit ->
        case Agents.update_agent(socket.assigns.agent, attrs, socket.assigns.current_scope.user) do
          {:ok, agent} ->
            {:noreply,
             socket
             |> put_flash(:info, "Agent updated.")
             |> assign_agent(agent)
             |> recompute_effective_tools()}

          {:error, changeset} ->
            {:noreply, assign_form(socket, changeset, attrs)}
        end
    end
  end

  @impl true
  def handle_event("publish", _params, socket) do
    case Agents.publish_agent(socket.assigns.agent, socket.assigns.current_scope.user) do
      {:ok, agent, _version} ->
        {:noreply,
         socket
         |> put_flash(:info, "Agent published.")
         |> assign_agent(agent)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Unable to publish.")}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_section", %{"section" => section}, socket) do
    expanded = socket.assigns.expanded_sections
    new_expanded = Map.update(expanded, section, true, &(!&1))
    {:noreply, assign(socket, :expanded_sections, new_expanded)}
  end

  @impl true
  def handle_event("search_channels", %{"channel_search" => query}, socket) do
    {:noreply, assign(socket, :channel_search, query)}
  end

  @impl true
  def handle_event("toggle_integration", %{"integrations" => params}, socket) do
    Enum.each(socket.assigns.integrations, fn integration ->
      enabled = Map.get(params, integration.id) == "true"
      _ = Agents.upsert_agent_integration(socket.assigns.agent.id, integration.id, enabled)
    end)

    new_states = integration_states(socket.assigns.agent, socket.assigns.integrations)

    {:noreply,
     socket
     |> assign(:integration_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("toggle_channel", %{"channels" => params}, socket) do
    # Track channels being enabled that aren't connected
    enabled_not_connected =
      socket.assigns.channels
      |> Enum.filter(fn channel ->
        was_disabled = not Map.get(socket.assigns.channel_states, channel.id, false)
        now_enabled = Map.get(params, channel.id) == "true"
        not_connected = not is_channel_connected?(socket.assigns.channel_health, channel.id)
        was_disabled and now_enabled and not_connected
      end)

    Enum.each(socket.assigns.channels, fn channel ->
      enabled = Map.get(params, channel.id) == "true"
      _ = Agents.upsert_agent_channel(socket.assigns.agent.id, channel.id, enabled)
    end)

    new_states = channel_states(socket.assigns.agent, socket.assigns.channels)

    socket =
      if length(enabled_not_connected) > 0 do
        put_flash(
          socket,
          :info,
          "Channel enabled but not connected. It won't send or receive until connected."
        )
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:channel_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("toggle_webhook", %{"webhooks" => params}, socket) do
    Enum.each(socket.assigns.webhooks, fn webhook ->
      enabled = Map.get(params, webhook.id) == "true"
      _ = Agents.upsert_agent_webhook(socket.assigns.agent.id, webhook.id, enabled)
    end)

    new_states = webhook_states(socket.assigns.agent, socket.assigns.webhooks)

    {:noreply,
     socket
     |> assign(:webhook_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("enable_all_channels", _params, socket) do
    Enum.each(socket.assigns.channels, fn channel ->
      _ = Agents.upsert_agent_channel(socket.assigns.agent.id, channel.id, true)
    end)

    new_states = channel_states(socket.assigns.agent, socket.assigns.channels)

    {:noreply,
     socket
     |> assign(:channel_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("disable_all_channels", _params, socket) do
    Enum.each(socket.assigns.channels, fn channel ->
      _ = Agents.upsert_agent_channel(socket.assigns.agent.id, channel.id, false)
    end)

    new_states = channel_states(socket.assigns.agent, socket.assigns.channels)

    {:noreply,
     socket
     |> assign(:channel_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("enable_connected_channels", _params, socket) do
    connected_channel_ids =
      socket.assigns.channel_health
      |> Enum.filter(fn {_id, health} -> (health.active_count || 0) > 0 end)
      |> Enum.map(fn {id, _health} -> id end)
      |> MapSet.new()

    Enum.each(socket.assigns.channels, fn channel ->
      enabled = MapSet.member?(connected_channel_ids, channel.id)
      _ = Agents.upsert_agent_channel(socket.assigns.agent.id, channel.id, enabled)
    end)

    new_states = channel_states(socket.assigns.agent, socket.assigns.channels)

    {:noreply,
     socket
     |> assign(:channel_states, new_states)
     |> recompute_effective_tools()}
  end

  @impl true
  def handle_event("open_scope_sheet", %{"channel_id" => channel_id}, socket) do
    tenant_id = socket.assigns.current_scope.tenant.id
    channel = Enum.find(socket.assigns.channels, &(&1.id == channel_id))
    health = Map.get(socket.assigns.channel_health, channel_id, %{})
    endpoints = Channels.list_endpoints(tenant_id, %{channel_id: channel_id})
    connections = Channels.channel_connections_by_endpoint(tenant_id, channel_id)

    # Get existing scope from agent_channel
    agent_channel = Agents.get_agent_channel(socket.assigns.agent.id, channel_id)
    {mode, selected_ids} = parse_scope(agent_channel && agent_channel.scope)

    {:noreply,
     socket
     |> assign(:scope_sheet_open, true)
     |> assign(:scope_channel, channel)
     |> assign(:scope_health, health)
     |> assign(:scope_endpoints, endpoints)
     |> assign(:scope_connections, connections)
     |> assign(:scope_mode, mode)
     |> assign(:scope_selected_ids, selected_ids)
     |> Fluxon.open_dialog("channel-scope-sheet")}
  end

  @impl true
  def handle_event("close_scope_sheet", _params, socket) do
    {:noreply, assign(socket, :scope_sheet_open, false)}
  end

  @impl true
  def handle_event("set_scope_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :scope_mode, mode)}
  end

  @impl true
  def handle_event("toggle_scope_endpoint", %{"endpoint_id" => endpoint_id}, socket) do
    current = socket.assigns.scope_selected_ids

    new_ids =
      if endpoint_id in current do
        List.delete(current, endpoint_id)
      else
        [endpoint_id | current]
      end

    {:noreply, assign(socket, :scope_selected_ids, new_ids)}
  end

  @impl true
  def handle_event("save_scope", _params, socket) do
    channel = socket.assigns.scope_channel

    scope =
      case socket.assigns.scope_mode do
        "all" -> %{"mode" => "all", "endpoint_ids" => []}
        "selected" -> %{"mode" => "selected", "endpoint_ids" => socket.assigns.scope_selected_ids}
      end

    enabled = Map.get(socket.assigns.channel_states, channel.id, false)
    _ = Agents.upsert_agent_channel(socket.assigns.agent.id, channel.id, enabled, scope)

    {:noreply,
     socket
     |> assign(:scope_sheet_open, false)
     |> put_flash(:info, "Channel scope updated.")}
  end

  @impl true
  def handle_event("view_integration_tools", %{"integration_id" => _integration_id}, socket) do
    # For now, tools are shown on hover via the expandable preview
    # Could later open a modal or sheet with full tool details
    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_avatar", _params, socket) do
    case Avatars.request_agent_avatar(socket.assigns.current_scope, socket.assigns.agent) do
      {:ok, avatar} ->
        {:noreply,
         socket
         |> assign(:avatar, avatar)
         |> put_flash(:info, "Avatar generation queued.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to queue avatar generation.")}
    end
  end

  # Private helpers

  defp assign_agent(socket, agent) do
    attrs = build_agent_attrs(%{}, agent)
    changeset = Agent.changeset(agent, attrs)

    socket
    |> assign(:agent, agent)
    |> assign_form(changeset, attrs)
    |> assign_avatar(agent)
  end

  defp assign_form(socket, changeset, attrs) do
    tool_policy = Map.get(attrs, :tool_policy, Agent.default_tool_policy())

    socket
    |> assign(:form, to_form(changeset, as: :agent))
    |> assign(:tool_allowlist, Enum.join(Map.get(tool_policy, "allow", []), "\n"))
    |> assign(:tool_denylist, Enum.join(Map.get(tool_policy, "deny", []), "\n"))
    |> assign(:max_calls_per_turn, Map.get(tool_policy, "max_calls_per_turn", 3))
    |> assign(:escalation_enabled, Map.get(attrs, :escalation_enabled, false))
    |> assign(:escalation_note, Map.get(attrs, :escalation_note, ""))
    |> assign(:channel_form, to_form(%{}, as: :channels))
    |> assign(:integration_form, to_form(%{}, as: :integrations))
    |> assign(:webhook_form, to_form(%{}, as: :webhooks))
  end

  defp assign_avatar(socket, %Agent{id: nil}), do: assign(socket, :avatar, nil)

  defp assign_avatar(socket, %Agent{} = agent) do
    avatar = Avatars.get_latest_avatar(socket.assigns.current_scope, agent.id)
    assign(socket, :avatar, avatar)
  end

  defp recompute_effective_tools(socket) do
    effective_tools =
      compute_effective_tools(
        socket.assigns.channels,
        socket.assigns.channel_states,
        socket.assigns.integrations,
        socket.assigns.integration_states,
        socket.assigns.webhooks,
        socket.assigns.webhook_states,
        socket.assigns.agent.tool_policy
      )

    assign(socket, :effective_tools, effective_tools)
  end

  defp compute_effective_tools(
         channels,
         channel_states,
         integrations,
         integration_states,
         webhooks,
         webhook_states,
         tool_policy
       ) do
    # Build tools with source tracking for deduplication
    channel_tools_with_sources =
      channels
      |> Enum.filter(fn c -> Map.get(channel_states, c.id, false) end)
      |> Enum.flat_map(fn c ->
        channel_tools(c) |> Enum.map(fn tool -> {tool, c.name} end)
      end)

    integration_tools_with_sources =
      integrations
      |> Enum.filter(fn i -> Map.get(integration_states, i.id, true) end)
      |> Enum.flat_map(fn i ->
        (i.allowed_tools || []) |> Enum.map(fn tool -> {tool, i.name} end)
      end)

    webhook_tools_with_sources =
      webhooks
      |> Enum.filter(fn w -> Map.get(webhook_states, w.id, true) end)
      |> Enum.map(fn w -> {w.tool_name, w.name} end)

    # Apply policy filtering
    allowlist = Map.get(tool_policy || %{}, "allow", [])
    denylist = Map.get(tool_policy || %{}, "deny", [])

    filter_tools = fn tools_with_sources ->
      tools_with_sources
      |> Enum.filter(fn {tool, _source} ->
        allowed =
          allowlist == [] or tool in allowlist or
            Enum.any?(allowlist, &String.contains?(tool, &1))

        not_denied =
          not Enum.member?(denylist, tool) and
            not Enum.any?(denylist, &String.contains?(tool, &1))

        allowed and not_denied
      end)
    end

    # Deduplicate tools and track all sources
    deduplicate_with_sources = fn tools_with_sources ->
      tools_with_sources
      |> Enum.group_by(fn {tool, _source} -> tool end, fn {_tool, source} -> source end)
      |> Enum.map(fn {tool, sources} -> {tool, Enum.uniq(sources)} end)
      |> Enum.sort_by(fn {tool, _} -> tool end)
    end

    filtered_channel = filter_tools.(channel_tools_with_sources) |> deduplicate_with_sources.()

    filtered_integration =
      filter_tools.(integration_tools_with_sources) |> deduplicate_with_sources.()

    filtered_webhook = filter_tools.(webhook_tools_with_sources) |> deduplicate_with_sources.()

    # Count grants (total including duplicates)
    channel_grant_count = length(channel_tools_with_sources)
    integration_grant_count = length(integration_tools_with_sources)
    webhook_grant_count = length(webhook_tools_with_sources)

    result = []

    result =
      if filtered_channel != [],
        do: result ++ [{:channels, filtered_channel, channel_grant_count}],
        else: result

    result =
      if filtered_integration != [],
        do: result ++ [{:integrations, filtered_integration, integration_grant_count}],
        else: result

    result =
      if filtered_webhook != [],
        do: result ++ [{:webhooks, filtered_webhook, webhook_grant_count}],
        else: result

    result
  end

  defp build_agent_attrs(params, agent) do
    instructions =
      Map.get(params, "instructions") || agent.instructions || Agent.default_instructions()

    base_tool_policy = agent.tool_policy || Agent.default_tool_policy()
    allowlist = Map.get(params, "tool_allowlist")
    denylist = Map.get(params, "tool_denylist")
    max_calls = Map.get(params, "max_calls_per_turn")

    tool_policy = %{
      "allow" =>
        if(is_nil(allowlist),
          do: Map.get(base_tool_policy, "allow", []),
          else: split_list(allowlist)
        ),
      "deny" =>
        if(is_nil(denylist),
          do: Map.get(base_tool_policy, "deny", []),
          else: split_list(denylist)
        ),
      "max_calls_per_turn" =>
        if(is_nil(max_calls),
          do: Map.get(base_tool_policy, "max_calls_per_turn", 3),
          else: parse_int(max_calls, 3)
        )
    }

    escalation = agent.escalation_policy || %{}

    escalation_enabled =
      if Map.has_key?(params, "escalation_enabled") do
        truthy?(Map.get(params, "escalation_enabled"))
      else
        Map.get(escalation, "enabled", false)
      end

    escalation_note =
      if Map.has_key?(params, "escalation_note") do
        Map.get(params, "escalation_note")
      else
        Map.get(escalation, "note", "")
      end

    escalation_policy =
      if escalation_enabled do
        %{"enabled" => true, "note" => escalation_note}
      else
        nil
      end

    %{
      name: Map.get(params, "name") || agent.name,
      status: Map.get(params, "status") || agent.status || "draft",
      language: Map.get(params, "language") || agent.language || "en-IN",
      voice_provider: Map.get(params, "voice_provider") || agent.voice_provider || "google",
      voice_name: Map.get(params, "voice_name") || agent.voice_name || "Fenrir",
      llm_provider: Map.get(params, "llm_provider") || agent.llm_provider || "google",
      llm_model: Map.get(params, "llm_model") || agent.llm_model || Agent.default_llm_model(),
      instructions: instructions,
      tool_policy: tool_policy,
      escalation_policy: escalation_policy,
      escalation_enabled: escalation_enabled,
      escalation_note: escalation_note
    }
  end

  defp channel_states(agent, channels) do
    states =
      Agents.list_agent_channels(agent.id)
      |> Map.new(fn ac -> {ac.channel_id, ac.enabled} end)

    Map.new(channels, fn channel ->
      {channel.id, Map.get(states, channel.id, false)}
    end)
  end

  defp integration_states(agent, integrations) do
    states =
      Agents.list_agent_integrations(agent.id)
      |> Map.new(fn ai -> {ai.integration_id, ai.enabled} end)

    Map.new(integrations, fn integration ->
      {integration.id, Map.get(states, integration.id, true)}
    end)
  end

  defp webhook_states(agent, webhooks) do
    states =
      Agents.list_agent_webhooks(agent.id)
      |> Map.new(fn aw -> {aw.webhook_id, aw.enabled} end)

    Map.new(webhooks, fn webhook ->
      {webhook.id, Map.get(states, webhook.id, true)}
    end)
  end

  defp parse_scope(nil), do: {"all", []}

  defp parse_scope(scope) when is_map(scope) do
    mode = Map.get(scope, "mode") || Map.get(scope, :mode) || "all"
    ids = Map.get(scope, "endpoint_ids") || Map.get(scope, :endpoint_ids) || []
    {to_string(mode), Enum.map(ids, &to_string/1)}
  end

  defp parse_scope(_), do: {"all", []}

  # UI helpers

  # Status helpers for character sheet
  defp status_ring_color("active"), do: "bg-success"
  defp status_ring_color("draft"), do: "bg-warning"
  defp status_ring_color("archived"), do: "bg-base-400"
  defp status_ring_color(_), do: "bg-base-400"

  defp status_glow_color("active"), do: "bg-success/40"
  defp status_glow_color("draft"), do: "bg-warning/30"
  defp status_glow_color("archived"), do: "bg-base-400/20"
  defp status_glow_color(_), do: "bg-base-400/20"

  defp status_icon("active"), do: "hero-check-mini"
  defp status_icon("draft"), do: "hero-pencil-mini"
  defp status_icon("archived"), do: "hero-archive-box-mini"
  defp status_icon(_), do: "hero-question-mark-circle-mini"

  defp status_chip_color("active"), do: "success"
  defp status_chip_color("draft"), do: "warning"
  defp status_chip_color("archived"), do: "info"
  defp status_chip_color(_), do: "info"

  defp language_short(nil), do: "—"

  defp language_short(lang) when is_binary(lang) do
    lang
    |> String.split("-")
    |> List.first()
    |> String.upcase()
  end

  defp model_short(nil), do: "—"

  defp model_short(model) when is_binary(model) do
    model
    |> String.split("/")
    |> List.last()
    |> String.slice(0..12)
    |> then(fn s -> if String.length(s) > 10, do: String.slice(s, 0..9) <> "…", else: s end)
  end

  defp instructions_word_count(nil), do: "0 words"

  defp instructions_word_count(text) when is_binary(text) do
    count = text |> String.split(~r/\s+/, trim: true) |> length()
    "#{count} words"
  end

  defp tab_icon("tools"), do: "hero-wrench-screwdriver"
  defp tab_icon("channels"), do: "hero-signal"
  defp tab_icon("integrations"), do: "hero-cube"
  defp tab_icon("webhooks"), do: "hero-bolt"
  defp tab_icon(_), do: "hero-squares-2x2"

  defp tab_count("tools", assigns), do: effective_tools_count(assigns.effective_tools)
  defp tab_count("channels", assigns), do: length(assigns.channels)
  defp tab_count("integrations", assigns), do: length(assigns.integrations)
  defp tab_count("webhooks", assigns), do: length(assigns.webhooks)
  defp tab_count(_, _), do: 0

  defp effective_tools_count(effective_tools) do
    effective_tools
    |> Enum.flat_map(fn {_source, tools, _grants} -> tools end)
    |> length()
  end

  defp effective_tools_grants(effective_tools) do
    effective_tools
    |> Enum.map(fn {_source, _tools, grants} -> grants end)
    |> Enum.sum()
  end

  defp source_icon(:channels), do: "hero-signal"
  defp source_icon(:integrations), do: "hero-cube"
  defp source_icon(:webhooks), do: "hero-bolt"
  defp source_icon(_), do: "hero-squares-2x2"

  defp source_label(:channels), do: "From Channels"
  defp source_label(:integrations), do: "From Integrations"
  defp source_label(:webhooks), do: "From Webhooks"
  defp source_label(_), do: "Other"

  defp channel_type_icon(:voice), do: "hero-phone"
  defp channel_type_icon(:email), do: "hero-envelope"
  defp channel_type_icon(:chat), do: "hero-chat-bubble-left-right"
  defp channel_type_icon(:whatsapp), do: "hero-chat-bubble-oval-left"
  defp channel_type_icon(_), do: "hero-signal"

  defp channel_type_gradient(:voice), do: "bg-gradient-to-br from-blue-500 to-cyan-600 text-white"
  defp channel_type_gradient(:email), do: "bg-gradient-to-br from-rose-500 to-pink-600 text-white"

  defp channel_type_gradient(:chat),
    do: "bg-gradient-to-br from-violet-500 to-purple-600 text-white"

  defp channel_type_gradient(:whatsapp),
    do: "bg-gradient-to-br from-green-500 to-emerald-600 text-white"

  defp channel_type_gradient(_), do: "bg-gradient-to-br from-slate-500 to-gray-600 text-white"

  defp channel_tools(channel) do
    (channel.capabilities || %{})
    |> Map.get("tools", [])
  end

  defp filter_channels(channels, ""), do: channels

  defp filter_channels(channels, query) do
    query_lower = String.downcase(query)

    Enum.filter(channels, fn c ->
      String.contains?(String.downcase(c.name), query_lower) or
        String.contains?(String.downcase(c.key), query_lower) or
        String.contains?(String.downcase(to_string(c.type)), query_lower)
    end)
  end

  # Sort channels: Connected+Enabled first, Connected+Disabled, Not connected last
  defp sort_channels(channels, channel_states, channel_health) do
    Enum.sort_by(channels, fn channel ->
      enabled = Map.get(channel_states, channel.id, false)
      connected = is_channel_connected?(channel_health, channel.id)

      case {connected, enabled} do
        # Connected + Enabled first
        {true, true} -> {0, channel.name}
        # Connected + Disabled
        {true, false} -> {1, channel.name}
        # Not connected + Enabled
        {false, true} -> {2, channel.name}
        # Not connected + Disabled last
        {false, false} -> {3, channel.name}
      end
    end)
  end

  defp is_channel_connected?(health_map, channel_id) do
    case Map.get(health_map, channel_id) do
      %{active_count: active} when active > 0 -> true
      _ -> false
    end
  end

  # Combined label showing both enabled state and connection status
  defp channel_combined_label(channel_states, health_map, channel_id) do
    enabled = Map.get(channel_states, channel_id, false)
    connected = is_channel_connected?(health_map, channel_id)
    has_errors = has_channel_errors?(health_map, channel_id)

    case {enabled, connected, has_errors} do
      {true, true, true} -> "Enabled · Needs attention"
      {true, true, false} -> "Enabled · Connected"
      {true, false, _} -> "Enabled · Not connected"
      {false, true, _} -> "Disabled · Connected"
      {false, false, _} -> "Disabled · Not connected"
    end
  end

  defp channel_combined_color(channel_states, health_map, channel_id) do
    enabled = Map.get(channel_states, channel_id, false)
    connected = is_channel_connected?(health_map, channel_id)
    has_errors = has_channel_errors?(health_map, channel_id)

    case {enabled, connected, has_errors} do
      {true, true, true} -> "warning"
      {true, true, false} -> "success"
      {true, false, _} -> "warning"
      {false, _, _} -> "info"
    end
  end

  defp has_channel_errors?(health_map, channel_id) do
    case Map.get(health_map, channel_id) do
      %{error_count: errors} when errors > 0 -> true
      _ -> false
    end
  end

  defp format_channel_type(type) when is_atom(type), do: Atom.to_string(type)
  defp format_channel_type(type) when is_binary(type), do: type
  defp format_channel_type(_), do: "unknown"

  defp has_channel_health?(health_map, channel_id) do
    Map.has_key?(health_map, channel_id)
  end

  defp has_custom_state?(channel_states, channel_id) do
    Map.has_key?(channel_states, channel_id)
  end

  defp channel_health_label(health_map, channel_id) do
    case Map.get(health_map, channel_id) do
      nil -> "Not connected"
      %{active_count: _active, error_count: error} when error > 0 -> "Needs attention"
      %{active_count: active} when active > 0 -> "Connected"
      _ -> "Not connected"
    end
  end

  defp channel_health_color(health_map, channel_id) do
    case Map.get(health_map, channel_id) do
      nil -> "warning"
      %{active_count: _active, error_count: error} when error > 0 -> "warning"
      %{active_count: active} when active > 0 -> "success"
      _ -> "warning"
    end
  end

  defp integration_status_color(:active), do: "success"
  defp integration_status_color(:disabled), do: "warning"
  defp integration_status_color(_), do: "info"

  defp webhook_status_color(:active), do: "success"
  defp webhook_status_color(:disabled), do: "warning"
  defp webhook_status_color(_), do: "info"

  defp endpoint_connection_label(connections_map, endpoint_id) do
    case Map.get(connections_map, endpoint_id) do
      nil ->
        "No connection"

      connections ->
        active = Enum.count(connections, &(&1.status == :active))
        if active > 0, do: "Connected", else: "Disconnected"
    end
  end

  defp endpoint_connection_color(connections_map, endpoint_id) do
    case Map.get(connections_map, endpoint_id) do
      nil ->
        "warning"

      connections ->
        active = Enum.count(connections, &(&1.status == :active))
        if active > 0, do: "success", else: "warning"
    end
  end

  defp format_relative_time(nil), do: "Never"

  defp format_relative_time(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end

  defp split_list(nil), do: []

  defp split_list(value) when is_binary(value) do
    value
    |> String.split(["\n", ","], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_int(nil, default), do: default

  defp parse_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(value, _default) when is_integer(value), do: value
  defp parse_int(_value, default), do: default

  defp truthy?(value) when value in [true, "true", "on", "1"], do: true
  defp truthy?(_value), do: false

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

  defp avatar_ready?(avatar) do
    avatar.status == :ready and is_binary(avatar.output_url)
  end

  defp avatar_status_label(nil), do: "No avatar yet"
  defp avatar_status_label(%{status: :queued}), do: "Avatar queued"
  defp avatar_status_label(%{status: :running}), do: "Avatar generating"
  defp avatar_status_label(%{status: :failed}), do: "Avatar failed"
  defp avatar_status_label(%{status: :ready}), do: "Avatar ready"
  defp avatar_status_label(_avatar), do: "Avatar pending"

  defp avatar_subtitle(nil, _tenant), do: "Generate a sticker-style avatar via Replicate."

  defp avatar_subtitle(%{status: :ready, generated_at: %DateTime{} = generated_at}, tenant) do
    "Generated #{Formatting.datetime(generated_at, tenant)}"
  end

  defp avatar_subtitle(%{status: :failed, error: error}, _tenant)
       when is_binary(error) and error != "" do
    avatar_error_message(error)
  end

  defp avatar_subtitle(%{status: :failed}, _tenant), do: "Try again to regenerate."
  defp avatar_subtitle(_avatar, _tenant), do: "Background job running."

  defp avatar_error_message(message) do
    if avatar_auth_error?(message) do
      "Replicate auth failed. Check REPLICATE_API_TOKEN."
    else
      message
    end
  end

  defp avatar_auth_error?(message) do
    message
    |> String.downcase()
    |> String.contains?("authentication token")
  end

  defp status_options do
    [
      {"Draft", "draft"},
      {"Active", "active"},
      {"Archived", "archived"}
    ]
  end

  defp language_options do
    indian =
      [
        {"English (India) - en-IN (hi-IN bundle)", "en-IN"},
        {"Hindi (India) - hi-IN", "hi-IN"},
        {"Marathi (India) - mr-IN", "mr-IN"},
        {"Tamil (India) - ta-IN", "ta-IN"},
        {"Telugu (India) - te-IN", "te-IN"}
      ]

    other =
      [
        {"Arabic (Egyptian) - ar-EG", "ar-EG"},
        {"Bengali (Bangladesh) - bn-BD", "bn-BD"},
        {"Dutch (Netherlands) - nl-NL", "nl-NL"},
        {"English (US) - en-US", "en-US"},
        {"French (France) - fr-FR", "fr-FR"},
        {"German (Germany) - de-DE", "de-DE"},
        {"Indonesian (Indonesia) - id-ID", "id-ID"},
        {"Italian (Italy) - it-IT", "it-IT"},
        {"Japanese (Japan) - ja-JP", "ja-JP"},
        {"Korean (Korea) - ko-KR", "ko-KR"},
        {"Polish (Poland) - pl-PL", "pl-PL"},
        {"Portuguese (Brazil) - pt-BR", "pt-BR"},
        {"Romanian (Romania) - ro-RO", "ro-RO"},
        {"Russian (Russia) - ru-RU", "ru-RU"},
        {"Spanish (US) - es-US", "es-US"},
        {"Thai (Thailand) - th-TH", "th-TH"},
        {"Turkish (Turkey) - tr-TR", "tr-TR"},
        {"Ukrainian (Ukraine) - uk-UA", "uk-UA"},
        {"Vietnamese (Vietnam) - vi-VN", "vi-VN"}
      ]

    indian ++ other
  end

  defp voice_options do
    [
      {"Zephyr - Bright", "Zephyr"},
      {"Kore - Firm", "Kore"},
      {"Orus - Firm", "Orus"},
      {"Autonoe - Bright", "Autonoe"},
      {"Umbriel - Easy-going", "Umbriel"},
      {"Erinome - Clear", "Erinome"},
      {"Laomedeia - Upbeat", "Laomedeia"},
      {"Schedar - Even", "Schedar"},
      {"Achird - Friendly", "Achird"},
      {"Sadachbia - Lively", "Sadachbia"},
      {"Puck - Upbeat", "Puck"},
      {"Fenrir - Excitable", "Fenrir"},
      {"Aoede - Breezy", "Aoede"},
      {"Enceladus - Breathy", "Enceladus"},
      {"Algieba - Smooth", "Algieba"},
      {"Algenib - Gravelly", "Algenib"},
      {"Achernar - Soft", "Achernar"},
      {"Gacrux - Mature", "Gacrux"},
      {"Zubenelgenubi - Casual", "Zubenelgenubi"},
      {"Sadaltager - Knowledgeable", "Sadaltager"},
      {"Charon - Informative", "Charon"},
      {"Leda - Youthful", "Leda"},
      {"Callirrhoe - Easy-going", "Callirrhoe"},
      {"Iapetus - Clear", "Iapetus"},
      {"Despina - Smooth", "Despina"},
      {"Rasalgethi - Informative", "Rasalgethi"},
      {"Alnilam - Firm", "Alnilam"},
      {"Pulcherrima - Forward", "Pulcherrima"},
      {"Vindemiatrix - Gentle", "Vindemiatrix"},
      {"Sulafat - Warm", "Sulafat"}
    ]
  end
end
