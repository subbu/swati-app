defmodule SwatiWeb.AgentsLive.Form do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Agents.Agent
  alias Swati.Integrations

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">{@page_title}</h1>
            <p class="text-sm text-base-content/70">Define instructions, voice, and tools.</p>
          </div>
          <div class="flex items-center gap-2">
            <.button :if={@live_action == :edit} phx-click="publish" variant="soft">Publish</.button>
            <.button navigate={~p"/agents"} variant="ghost">Back</.button>
          </div>
        </div>

        <.form for={@form} id="agent-form" phx-change="validate" phx-submit="save">
          <div class="grid gap-6">
            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Basics</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@form[:name]} label="Agent name" required />
                <.select field={@form[:status]} label="Status" options={@status_options} />
                <.select
                  field={@form[:language]}
                  label="Language"
                  options={@language_options}
                />
                <.input field={@form[:llm_model]} label="LLM model" />
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Voice</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@form[:voice_provider]} label="Voice provider" />
                <.select
                  field={@form[:voice_name]}
                  label="Voice name"
                  options={@voice_options}
                />
                <.input field={@form[:llm_provider]} label="LLM provider" />
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Agent instructions</h2>
              <.textarea field={@form[:instructions]} label="Agent instructions" rows={10} />
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Tool policy</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.textarea name="agent[tool_allowlist]" label="Allowed tools" value={@tool_allowlist} />
                <.textarea name="agent[tool_denylist]" label="Denied tools" value={@tool_denylist} />
                <.input
                  name="agent[max_calls_per_turn]"
                  label="Max calls per turn"
                  type="number"
                  value={@max_calls_per_turn}
                />
              </div>
            </section>

            <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
              <h2 class="text-lg font-semibold">Escalation policy</h2>
              <div class="grid gap-4 md:grid-cols-2">
                <.switch
                  name="agent[escalation_enabled]"
                  label="Enable escalation"
                  checked={@escalation_enabled}
                />
                <.input
                  name="agent[escalation_note]"
                  label="Escalation note"
                  value={@escalation_note}
                />
              </div>
            </section>
          </div>

          <div class="flex justify-end">
            <.button type="submit">Save agent</.button>
          </div>
        </.form>

        <section
          :if={@live_action == :edit}
          class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4"
        >
          <h2 class="text-lg font-semibold">Integrations</h2>
          <p class="text-sm text-base-content/70">Toggle which tools are available to this agent.</p>
          <.form for={@integration_form} id="agent-integrations" phx-change="toggle_integration">
            <div class="grid gap-2">
              <div
                :for={integration <- @integrations}
                class="flex items-center justify-between rounded-xl border border-base-300 px-4 py-3"
              >
                <div>
                  <p class="font-medium">{integration.name}</p>
                  <p class="text-xs text-base-content/60">{integration.endpoint_url}</p>
                </div>
                <.switch
                  name={"integrations[#{integration.id}]"}
                  checked={Map.get(@integration_states, integration.id, true)}
                />
              </div>
            </div>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:status_options, status_options())
     |> assign(:language_options, language_options())
     |> assign(:voice_options, voice_options())
     |> assign(:integrations, [])
     |> assign(:integration_states, %{})}
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
        agent = Agents.get_agent!(socket.assigns.current_scope.tenant.id, params["id"])
        integrations = Integrations.list_integrations(socket.assigns.current_scope.tenant.id)
        states = integration_states(agent, integrations)

        {:noreply,
         socket
         |> assign(:page_title, "Edit agent")
         |> assign(:integrations, integrations)
         |> assign(:integration_states, states)
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
             |> assign_agent(agent)}

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
  def handle_event("toggle_integration", %{"integrations" => params}, socket) do
    Enum.each(socket.assigns.integrations, fn integration ->
      enabled = Map.get(params, integration.id) == "true"
      _ = Agents.upsert_agent_integration(socket.assigns.agent.id, integration.id, enabled)
    end)

    {:noreply,
     assign(
       socket,
       :integration_states,
       integration_states(socket.assigns.agent, socket.assigns.integrations)
     )}
  end

  defp assign_agent(socket, agent) do
    attrs = build_agent_attrs(%{}, agent)
    changeset = Agent.changeset(agent, attrs)

    socket
    |> assign(:agent, agent)
    |> assign_form(changeset, attrs)
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
    |> assign(:integration_form, to_form(%{}, as: :integrations))
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

  defp integration_states(agent, integrations) do
    states =
      Agents.list_agent_integrations(agent.id)
      |> Map.new(fn ai -> {ai.integration_id, ai.enabled} end)

    Map.new(integrations, fn integration ->
      {integration.id, Map.get(states, integration.id, true)}
    end)
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
