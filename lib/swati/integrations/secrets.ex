defmodule Swati.Integrations.Secrets do
  import Ecto.Query, warn: false

  alias Swati.Integrations.Integration
  alias Swati.Integrations.Queries
  alias Swati.Integrations.Secret
  alias Swati.Repo

  def list_integrations_with_secrets(tenant_id, agent_id \\ nil) do
    integrations =
      case agent_id do
        nil -> Queries.list_integrations(tenant_id)
        agent_id -> Queries.list_integrations_for_agent(tenant_id, agent_id)
      end

    secret_ids =
      integrations
      |> Enum.map(& &1.auth_secret_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    secrets =
      case secret_ids do
        [] -> %{}
        _ -> Repo.all(from(s in Secret, where: s.id in ^secret_ids))
      end
      |> Map.new(fn secret -> {secret.id, secret} end)

    Enum.map(integrations, fn integration ->
      {integration, Map.get(secrets, integration.auth_secret_id)}
    end)
  end

  def auth_headers(%Integration{auth_type: :bearer, auth_secret_id: secret_id})
      when is_binary(secret_id) do
    case Repo.get(Secret, secret_id) do
      %Secret{value: token} -> [{"authorization", "Bearer #{token}"}]
      _ -> []
    end
  end

  def auth_headers(_integration), do: []

  def upsert(repo, tenant_id, attrs, auth_token, integration \\ nil) do
    auth_type = Map.get(attrs, "auth_type", :none)

    cond do
      auth_type != :bearer ->
        {:ok, nil}

      is_nil(auth_token) and is_nil(integration) ->
        {:error, "auth_token_required"}

      (is_nil(auth_token) and integration) && integration.auth_secret_id ->
        {:ok, repo.get(Secret, integration.auth_secret_id)}

      (is_nil(auth_token) and integration) && is_nil(integration.auth_secret_id) ->
        {:error, "auth_token_required"}

      true ->
        secret_attrs = %{
          tenant_id: tenant_id,
          name: secret_name(attrs, integration),
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

  defp secret_name(attrs, integration) do
    name = Map.get(attrs, "name") || (integration && integration.name) || "integration"
    "integration:#{name}:bearer"
  end
end
