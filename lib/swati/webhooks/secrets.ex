defmodule Swati.Webhooks.Secrets do
  import Ecto.Query, warn: false

  alias Swati.Integrations.Secret
  alias Swati.Repo
  alias Swati.Webhooks.Queries
  alias Swati.Webhooks.Webhook

  def list_webhooks_with_secrets(tenant_id, agent_id \\ nil) do
    webhooks =
      case agent_id do
        nil -> Queries.list_webhooks(tenant_id)
        agent_id -> Queries.list_webhooks_for_agent(tenant_id, agent_id)
      end

    secret_ids =
      webhooks
      |> Enum.map(& &1.auth_secret_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    secrets =
      case secret_ids do
        [] -> %{}
        _ -> Repo.all(from(s in Secret, where: s.id in ^secret_ids))
      end
      |> Map.new(fn secret -> {secret.id, secret} end)

    Enum.map(webhooks, fn webhook ->
      {webhook, Map.get(secrets, webhook.auth_secret_id)}
    end)
  end

  def auth_headers(%Webhook{auth_type: :bearer, auth_secret_id: secret_id})
      when is_binary(secret_id) do
    case Repo.get(Secret, secret_id) do
      %Secret{value: token} -> [{"authorization", "Bearer #{token}"}]
      _ -> []
    end
  end

  def auth_headers(_webhook), do: []

  def upsert(repo, tenant_id, attrs, auth_token, webhook \\ nil) do
    auth_type = Map.get(attrs, "auth_type", :none)

    cond do
      auth_type != :bearer ->
        {:ok, nil}

      is_nil(auth_token) and is_nil(webhook) ->
        {:error, "auth_token_required"}

      (is_nil(auth_token) and webhook) && webhook.auth_secret_id ->
        {:ok, repo.get(Secret, webhook.auth_secret_id)}

      (is_nil(auth_token) and webhook) && is_nil(webhook.auth_secret_id) ->
        {:error, "auth_token_required"}

      true ->
        secret_attrs = %{
          tenant_id: tenant_id,
          name: secret_name(attrs, webhook),
          value: auth_token
        }

        changeset = Secret.changeset(%Secret{}, secret_attrs)

        repo.insert(changeset,
          on_conflict: [set: [value: auth_token, updated_at: DateTime.utc_now()]],
          conflict_target: [:tenant_id, :name]
        )
    end
  end

  def put_secret_id(attrs, nil), do: attrs
  def put_secret_id(attrs, %Secret{id: id}), do: Map.put(attrs, "auth_secret_id", id)

  defp secret_name(attrs, webhook) do
    name = Map.get(attrs, "name") || (webhook && webhook.name) || "webhook"
    "webhook:#{name}:bearer"
  end
end
