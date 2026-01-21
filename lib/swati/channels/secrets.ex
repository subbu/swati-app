defmodule Swati.Channels.Secrets do
  alias Swati.Channels.ChannelConnection
  alias Swati.Integrations.Secret

  def get_secret_value(%ChannelConnection{auth_secret_id: nil}), do: nil

  def get_secret_value(%ChannelConnection{auth_secret_id: secret_id}) do
    case Swati.Repo.get(Secret, secret_id) do
      %Secret{value: value} -> value
      _ -> nil
    end
  end

  def upsert(repo, tenant_id, attrs, secret_value, connection \\ nil) do
    cond do
      (is_nil(secret_value) and connection) && connection.auth_secret_id ->
        {:ok, repo.get(Secret, connection.auth_secret_id)}

      is_nil(secret_value) ->
        {:ok, nil}

      true ->
        secret_attrs = %{
          tenant_id: tenant_id,
          name: secret_name(attrs, connection),
          value: secret_value
        }

        changeset = Secret.changeset(%Secret{}, secret_attrs)

        repo.insert(changeset,
          on_conflict: [set: [value: secret_value, updated_at: DateTime.utc_now()]],
          conflict_target: [:tenant_id, :name]
        )
    end
  end

  def put_secret_id(attrs, nil), do: attrs
  def put_secret_id(attrs, %Secret{id: id}), do: Map.put(attrs, "auth_secret_id", id)

  defp secret_name(attrs, connection) do
    provider = Map.get(attrs, "provider") || (connection && connection.provider) || "channel"
    channel_id = Map.get(attrs, "channel_id") || (connection && connection.channel_id)
    endpoint_id = Map.get(attrs, "endpoint_id") || (connection && connection.endpoint_id)

    "channel:#{provider}:#{channel_id}:#{endpoint_id}"
  end
end
