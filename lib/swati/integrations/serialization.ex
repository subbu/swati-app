defmodule Swati.Integrations.Serialization do
  def public_payload(integration) do
    %{
      id: integration.id,
      type: integration.type,
      name: integration.name,
      endpoint: integration.endpoint_url,
      origin: integration.origin,
      protocol_version: integration.protocol_version,
      timeout_secs: integration.timeout_secs,
      status: integration.status,
      allowed_tools: integration.allowed_tools,
      tool_prefix: integration.tool_prefix,
      auth_type: integration.auth_type
    }
  end

  def internal_payload(integration, secret) do
    token = if secret, do: secret.value

    auth =
      case integration.auth_type do
        :bearer -> %{type: :bearer, token: token}
        _ -> %{type: :none}
      end

    public_payload(integration)
    |> Map.put(:auth, auth)
  end
end
