defmodule Swati.Runtime do
  alias Swati.Agents
  alias Swati.Agents.EscalationPolicy
  alias Swati.Agents.ToolPolicy
  alias Swati.Integrations
  alias Swati.Integrations.Serialization
  alias Swati.RuntimeConfig
  alias Swati.Webhooks
  alias Swati.Webhooks.Serialization, as: WebhookSerialization
  alias Swati.Telephony
  alias Swati.Tenancy

  @spec runtime_config_for_phone_number(binary()) ::
          {:ok, map()} | {:error, :phone_number_missing_agent | :agent_not_published}
  def runtime_config_for_phone_number(phone_number) when is_binary(phone_number) do
    phone_number = Telephony.get_phone_number_by_e164!(phone_number)
    tenant = Tenancy.get_tenant!(phone_number.tenant_id)

    case phone_number.inbound_agent_id do
      nil ->
        {:error, :phone_number_missing_agent}

      agent_id ->
        agent = Agents.get_agent!(tenant.id, agent_id)

        case agent.published_version do
          nil ->
            {:error, :agent_not_published}

          version ->
            integrations = Integrations.list_integrations_with_secrets(tenant.id, agent.id)
            webhooks = Webhooks.list_webhooks_with_secrets(tenant.id, agent.id)
            tool_policy = ToolPolicy.effective(version.config, integrations, webhooks)

            integrations_json =
              Enum.map(integrations, fn {integration, secret} ->
                Serialization.internal_payload(integration, secret)
              end)

            webhooks_json =
              Enum.map(webhooks, fn {webhook, secret} ->
                WebhookSerialization.internal_payload(webhook, secret)
              end)

            {:ok,
             %{
               config_version: RuntimeConfig.version(),
               tenant: %{id: tenant.id, name: tenant.name, timezone: tenant.timezone},
               phone_number: %{
                 id: phone_number.id,
                 e164: phone_number.e164,
                 provider: phone_number.provider
               },
               agent: agent_payload(agent, version.config, tool_policy),
               integrations: integrations_json,
               webhooks: webhooks_json,
               logging: %{
                 recording: %{
                   enabled: true,
                   record_caller: true,
                   record_agent: true,
                   generate_stereo: true
                 },
                 retention_days: 30
               }
             }}
        end
    end
  end

  defp agent_payload(agent, config, tool_policy) do
    config = config || %{}

    %{
      id: agent.id,
      name: agent.name,
      language: Map.get(config, "language") || agent.language,
      voice:
        Map.get(config, "voice") || %{provider: agent.voice_provider, name: agent.voice_name},
      llm: Map.get(config, "llm") || %{provider: agent.llm_provider, model: agent.llm_model},
      system_prompt: Map.get(config, "system_prompt"),
      tool_policy: tool_policy,
      escalation_policy: EscalationPolicy.normalize(Map.get(config, "escalation_policy"))
    }
  end
end
