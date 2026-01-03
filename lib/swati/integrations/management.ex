defmodule Swati.Integrations.Management do
  alias Swati.Audit
  alias Swati.Integrations.Attrs
  alias Swati.Integrations.Integration
  alias Swati.Integrations.Secrets
  alias Swati.Repo

  def create_integration(tenant_id, attrs, actor) do
    attrs = Attrs.normalize(attrs)
    auth_token = Map.get(attrs, "auth_token")

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:secret, fn repo, _ ->
        Secrets.upsert(repo, tenant_id, attrs, auth_token)
      end)
      |> Ecto.Multi.insert(:integration, fn %{secret: secret} ->
        integration_attrs =
          attrs
          |> Map.drop(["auth_token"])
          |> Map.put("tenant_id", tenant_id)
          |> Secrets.put_secret_id(secret)

        Integration.changeset(%Integration{}, integration_attrs)
      end)
      |> Ecto.Multi.run(:audit, fn _repo, %{integration: integration} ->
        Audit.log(
          tenant_id,
          actor.id,
          "integration.create",
          "integration",
          integration.id,
          attrs,
          %{}
        )

        {:ok, :logged}
      end)

    case Repo.transaction(multi) do
      {:ok, %{integration: integration}} -> {:ok, integration}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def update_integration(%Integration{} = integration, attrs, actor) do
    attrs = Attrs.normalize(attrs)
    auth_token = Map.get(attrs, "auth_token")

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:secret, fn repo, _ ->
        Secrets.upsert(repo, integration.tenant_id, attrs, auth_token, integration)
      end)
      |> Ecto.Multi.update(:integration, fn %{secret: secret} ->
        integration_attrs =
          attrs
          |> Map.drop(["auth_token"])
          |> Secrets.put_secret_id(secret)

        Integration.changeset(integration, integration_attrs)
      end)
      |> Ecto.Multi.run(:audit, fn _repo, %{integration: integration} ->
        Audit.log(
          integration.tenant_id,
          actor.id,
          "integration.update",
          "integration",
          integration.id,
          attrs,
          %{}
        )

        {:ok, :logged}
      end)

    case Repo.transaction(multi) do
      {:ok, %{integration: integration}} -> {:ok, integration}
      {:error, _step, %Ecto.Changeset{} = changeset, _} -> {:error, changeset}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def delete_integration(%Integration{} = integration, actor) do
    case Repo.delete(integration) do
      {:ok, integration} ->
        Audit.log(
          integration.tenant_id,
          actor.id,
          "integration.delete",
          "integration",
          integration.id,
          %{},
          %{}
        )

        {:ok, integration}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
