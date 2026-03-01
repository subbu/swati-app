defmodule Swati.Inbound.Commands do
  alias Swati.Inbound.AgentRule
  alias Swati.Inbound.Connector
  alias Swati.Inbound.Delivery
  alias Swati.Inbound.ThreadOwnershipEvent
  alias Swati.Inbound.Secrets
  alias Swati.Repo

  def create_connector(tenant_id, attrs) do
    attrs = attrs || %{}
    signing_secret = Map.get(attrs, "signing_secret") || Map.get(attrs, :signing_secret)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:signing_secret, fn repo, _ ->
        connector_name =
          Map.get(attrs, "name") || Map.get(attrs, :name) ||
            "connector-#{System.unique_integer()}"

        Secrets.upsert_signing_secret(repo, tenant_id, to_string(connector_name), signing_secret)
      end)
      |> Ecto.Multi.insert(:connector, fn %{signing_secret: secret} ->
        token = generate_endpoint_token()

        connector_attrs =
          attrs
          |> stringify_keys()
          |> Map.drop(["signing_secret"])
          |> Map.put("tenant_id", tenant_id)
          |> Map.put_new("provider", "resend")
          |> Map.put_new("status", "active")
          |> Map.put_new("endpoint_token", token)
          |> Map.put_new("default_channel_key", "email")
          |> Map.put_new("routing_mode", "continuity_first")
          |> Secrets.put_signing_secret_id(secret)

        %Connector{}
        |> Connector.changeset(connector_attrs)
      end)

    case Repo.transaction(multi) do
      {:ok, %{connector: connector}} -> {:ok, connector}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def update_connector(%Connector{} = connector, attrs) do
    attrs = attrs || %{}
    signing_secret = Map.get(attrs, "signing_secret") || Map.get(attrs, :signing_secret)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:signing_secret, fn repo, _ ->
        if is_binary(signing_secret) do
          Secrets.upsert_signing_secret(repo, connector.tenant_id, connector.name, signing_secret)
        else
          {:ok, nil}
        end
      end)
      |> Ecto.Multi.update(:connector, fn %{signing_secret: secret} ->
        connector_attrs =
          attrs
          |> stringify_keys()
          |> Map.drop(["signing_secret"])
          |> maybe_put_signing_secret_id(secret)

        Connector.changeset(connector, connector_attrs)
      end)

    case Repo.transaction(multi) do
      {:ok, %{connector: connector}} -> {:ok, connector}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def delete_connector(%Connector{} = connector), do: Repo.delete(connector)

  def create_rule(tenant_id, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", tenant_id)
      |> Map.put_new("enabled", true)
      |> Map.put_new("priority", 100)
      |> Map.put_new("action", "owner")
      |> Map.put_new("predicates", %{})

    %AgentRule{}
    |> AgentRule.changeset(attrs)
    |> Repo.insert()
  end

  def update_rule(%AgentRule{} = rule, attrs) do
    rule
    |> AgentRule.changeset(stringify_keys(attrs || %{}))
    |> Repo.update()
  end

  def delete_rule(%AgentRule{} = rule), do: Repo.delete(rule)

  def create_delivery(attrs) do
    %Delivery{}
    |> Delivery.changeset(attrs)
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: [:connector_id, :idempotency_key],
      returning: true
    )
  end

  def update_delivery(%Delivery{} = delivery, attrs) do
    delivery
    |> Delivery.changeset(attrs)
    |> Repo.update()
  end

  def create_thread_ownership_event(attrs) do
    %ThreadOwnershipEvent{}
    |> ThreadOwnershipEvent.changeset(attrs)
    |> Repo.insert()
  end

  defp maybe_put_signing_secret_id(attrs, nil), do: attrs

  defp maybe_put_signing_secret_id(attrs, %{id: id}) do
    Map.put(attrs, "signing_secret_id", id)
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end

  defp generate_endpoint_token do
    :crypto.strong_rand_bytes(24)
    |> Base.url_encode64(padding: false)
  end
end
