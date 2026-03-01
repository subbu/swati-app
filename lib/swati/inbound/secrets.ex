defmodule Swati.Inbound.Secrets do
  alias Swati.Integrations.Secret
  alias Swati.Repo

  def get_secret_value(nil), do: nil

  def get_secret_value(secret_id) when is_binary(secret_id) do
    case Repo.get(Secret, secret_id) do
      %Secret{value: value} when is_binary(value) -> value
      _ -> nil
    end
  end

  def upsert_signing_secret(_repo, _tenant_id, _connector_name, nil), do: {:ok, nil}

  def upsert_signing_secret(repo, tenant_id, connector_name, value) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:ok, nil}
    else
      secret_attrs = %{
        tenant_id: tenant_id,
        name: "inbound:#{connector_name}:signing",
        value: trimmed
      }

      changeset = Secret.changeset(%Secret{}, secret_attrs)

      repo.insert(changeset,
        on_conflict: [set: [value: trimmed, updated_at: DateTime.utc_now()]],
        conflict_target: [:tenant_id, :name],
        returning: true
      )
    end
  end

  def put_signing_secret_id(attrs, nil), do: attrs
  def put_signing_secret_id(attrs, %Secret{id: id}), do: Map.put(attrs, "signing_secret_id", id)
end
