defmodule Swati.Webhooks.Serialization do
  def public_payload(webhook) do
    %{
      id: webhook.id,
      name: webhook.name,
      tool_name: webhook.tool_name,
      description: webhook.description,
      endpoint: webhook.endpoint_url,
      http_method: webhook.http_method,
      timeout_secs: webhook.timeout_secs,
      status: webhook.status,
      headers: webhook.headers,
      input_schema: webhook.input_schema
    }
  end

  def internal_payload(webhook, secret) do
    token = if secret, do: secret.value

    auth =
      case webhook.auth_type do
        :bearer -> %{type: :bearer, token: token}
        _ -> %{type: :none}
      end

    public_payload(webhook)
    |> Map.put(:auth, auth)
  end
end
