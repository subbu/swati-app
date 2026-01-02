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
            tool_policy = effective_tool_policy(version.config, integrations)

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
              agent: agent_payload(agent, version.config, tool_policy),
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

  defp agent_payload(agent, config, tool_policy) do
    %{
      id: agent.id,
      name: agent.name,
      language: Map.get(config, "language") || agent.language,
      voice:
        Map.get(config, "voice") || %{provider: agent.voice_provider, name: agent.voice_name},
      llm: Map.get(config, "llm") || %{provider: agent.llm_provider, model: agent.llm_model},
      system_prompt: Map.get(config, "system_prompt"),
      tool_policy: tool_policy,
      escalation_policy: Map.get(config, "escalation_policy")
    }
  end

  defp effective_tool_policy(config, integrations) do
    base_policy = Map.get(config || %{}, "tool_policy") || %{}
    base_allow = list_value(base_policy, "allow")
    base_deny = list_value(base_policy, "deny")
    base_max_calls = integer_value(base_policy, "max_calls_per_turn", 3)
    integration_allow = integration_allowed_tools(integrations)

    allow =
      cond do
        base_allow != [] and integration_allow != [] ->
          Enum.filter(base_allow, &(&1 in integration_allow))

        base_allow != [] ->
          base_allow

        integration_allow != [] ->
          integration_allow

        true ->
          []
      end

    allow =
      if base_deny == [] or allow == [] do
        allow
      else
        Enum.reject(allow, &(&1 in base_deny))
      end

    %{
      "allow" => allow,
      "deny" => base_deny,
      "max_calls_per_turn" => base_max_calls
    }
  end

  defp integration_allowed_tools(integrations) do
    integrations
    |> Enum.flat_map(fn {integration, _secret} -> integration.allowed_tools || [] end)
    |> Enum.map(&to_string/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp list_value(policy, key) when is_map(policy) do
    value = Map.get(policy, key) || Map.get(policy, String.to_atom(key))
    if is_list(value), do: value, else: []
  end

  defp list_value(_policy, _key), do: []

  defp integer_value(policy, key, default) when is_map(policy) do
    value = Map.get(policy, key) || Map.get(policy, String.to_atom(key))
    if is_integer(value), do: value, else: default
  end

  defp integer_value(_policy, _key, default), do: default
end
