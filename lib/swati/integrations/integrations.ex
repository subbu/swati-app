defmodule Swati.Integrations do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Agents.AgentIntegration
  alias Swati.Integrations.{Integration, Secret}

  def list_integrations(tenant_id) do
    Integration
    |> Tenancy.scope(tenant_id)
    |> Repo.all()
  end

  def get_integration!(tenant_id, integration_id) do
    Integration
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(integration_id)
  end

  def list_integrations_for_agent(tenant_id, agent_id) do
    from(i in Integration,
      left_join: ai in AgentIntegration,
      on: ai.integration_id == i.id and ai.agent_id == ^agent_id,
      where: i.tenant_id == ^tenant_id,
      where: i.status == :active,
      where: is_nil(ai.id) or ai.enabled == true,
      order_by: [asc: i.name]
    )
    |> Repo.all()
  end

  def list_integrations_with_secrets(tenant_id, agent_id \\ nil) do
    integrations =
      case agent_id do
        nil -> list_integrations(tenant_id)
        agent_id -> list_integrations_for_agent(tenant_id, agent_id)
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

  def create_integration(tenant_id, attrs, actor) do
    attrs = normalize_attrs(attrs)
    auth_token = Map.get(attrs, "auth_token")

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:secret, fn repo, _ ->
        maybe_upsert_secret(repo, tenant_id, attrs, auth_token)
      end)
      |> Ecto.Multi.insert(:integration, fn %{secret: secret} ->
        integration_attrs =
          attrs
          |> Map.drop(["auth_token"])
          |> Map.put("tenant_id", tenant_id)
          |> maybe_put_secret_id(secret)

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
    attrs = normalize_attrs(attrs)
    auth_token = Map.get(attrs, "auth_token")

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:secret, fn repo, _ ->
        maybe_upsert_secret(repo, integration.tenant_id, attrs, auth_token, integration)
      end)
      |> Ecto.Multi.update(:integration, fn %{secret: secret} ->
        integration_attrs =
          attrs
          |> Map.drop(["auth_token"])
          |> maybe_put_secret_id(secret)

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

  def test_integration(%Integration{type: :mcp_streamable_http} = integration) do
    headers = auth_headers(integration)
    request = Req.new(method: :head, url: integration.endpoint_url, headers: headers)

    result =
      case Req.request(request) do
        {:ok, %{status: status}} when status in 200..399 ->
          {:ok, "success", nil}

        {:ok, %{status: status}} ->
          {:error, "error", "Unexpected status: #{status}"}

        {:error, error} ->
          {:error, "error", Exception.message(error)}
      end

    update_test_status(integration, result)
  end

  def test_integration(%Integration{} = integration) do
    update_test_status(integration, {:error, "error", "Unsupported integration type"})
  end

  defp update_test_status(integration, {status, label, error}) do
    changes = %{
      last_tested_at: DateTime.utc_now(),
      last_test_status: label,
      last_test_error: error
    }

    integration
    |> Ecto.Changeset.change(changes)
    |> Repo.update()
    |> case do
      {:ok, integration} -> {status, integration}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp auth_headers(%Integration{auth_type: :bearer, auth_secret_id: secret_id})
       when is_binary(secret_id) do
    case Repo.get(Secret, secret_id) do
      %Secret{value: token} -> [{"authorization", "Bearer #{token}"}]
      _ -> []
    end
  end

  defp auth_headers(_integration), do: []

  defp maybe_upsert_secret(repo, tenant_id, attrs, auth_token, integration \\ nil) do
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

  defp secret_name(attrs, integration) do
    name = Map.get(attrs, "name") || (integration && integration.name) || "integration"
    "integration:#{name}:bearer"
  end

  defp normalize_attrs(attrs) do
    attrs
    |> Map.new(fn {key, value} -> {to_string(key), value} end)
    |> normalize_allowed_tools()
    |> normalize_auth_type()
    |> normalize_type()
  end

  defp normalize_allowed_tools(attrs) do
    allowed_tools = Map.get(attrs, "allowed_tools")

    list =
      cond do
        is_list(allowed_tools) ->
          allowed_tools

        is_binary(allowed_tools) ->
          allowed_tools
          |> String.split(["\n", ","], trim: true)
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))

        true ->
          []
      end

    Map.put(attrs, "allowed_tools", list)
  end

  defp normalize_auth_type(attrs) do
    auth_type = Map.get(attrs, "auth_type") || :none
    Map.put(attrs, "auth_type", to_enum(auth_type))
  end

  defp normalize_type(attrs) do
    type = Map.get(attrs, "type")

    normalized =
      case type do
        nil -> :mcp_streamable_http
        "" -> :mcp_streamable_http
        _ -> to_enum(type)
      end

    Map.put(attrs, "type", normalized)
  end

  defp to_enum(value) when is_atom(value), do: value

  defp to_enum(value) when is_binary(value) do
    case value do
      "mcp_streamable_http" -> :mcp_streamable_http
      "bearer" -> :bearer
      "none" -> :none
      "active" -> :active
      "disabled" -> :disabled
      _ -> :none
    end
  end

  defp maybe_put_secret_id(attrs, nil), do: attrs
  defp maybe_put_secret_id(attrs, %Secret{id: id}), do: Map.put(attrs, "auth_secret_id", id)
end
