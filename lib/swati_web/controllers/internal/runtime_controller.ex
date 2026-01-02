defmodule SwatiWeb.Internal.RuntimeController do
  use SwatiWeb, :controller

  alias Swati.Agents
  alias Swati.Integrations
  alias Swati.RuntimeConfig
  alias Swati.Telephony
  alias Swati.Tenancy
  alias SwatiWeb.IntegrationView

  def show(conn, %{"phone_number_id" => phone_number_id}) do
    phone_number = Telephony.get_phone_number!(phone_number_id)
    tenant = Tenancy.get_tenant!(phone_number.tenant_id)

    case phone_number.inbound_agent_id do
      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "phone_number_missing_agent"})

      agent_id ->
        agent = Agents.get_agent!(tenant.id, agent_id)

        case agent.published_version do
          nil ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "agent_not_published"})

          version ->
            integrations = Integrations.list_integrations_with_secrets(tenant.id, agent.id)

            integrations_json =
              Enum.map(integrations, fn {integration, secret} ->
                token = secret && secret.value
                IntegrationView.internal_json(integration, token)
              end)

            json(conn, %{
              config_version: RuntimeConfig.version(),
              tenant: %{id: tenant.id, name: tenant.name, timezone: tenant.timezone},
              phone_number: %{
                id: phone_number.id,
                e164: phone_number.e164,
                provider: phone_number.provider
              },
              agent: agent_payload(agent, version.config),
              integrations: integrations_json,
              logging: %{
                recording: %{
                  enabled: true,
                  record_caller: true,
                  record_agent: true,
                  generate_stereo: true
                },
                retention_days: 30
              }
            })
        end
    end
  end

  defp agent_payload(agent, config) do
    %{
      id: agent.id,
      name: agent.name,
      language: Map.get(config, "language") || agent.language,
      voice:
        Map.get(config, "voice") || %{provider: agent.voice_provider, name: agent.voice_name},
      llm: Map.get(config, "llm") || %{provider: agent.llm_provider, model: agent.llm_model},
      system_prompt: Map.get(config, "system_prompt"),
      tool_policy: Map.get(config, "tool_policy"),
      escalation_policy: Map.get(config, "escalation_policy")
    }
  end
end
