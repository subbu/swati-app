defmodule Swati.Agents do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Agents.{Agent, AgentChannel, AgentIntegration, AgentWebhook, AgentVersion, Compiler}

  def list_agents(tenant_id) do
    Agent
    |> Tenancy.scope(tenant_id)
    |> Repo.all()
  end

  def get_agent!(tenant_id, agent_id) do
    Agent
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(agent_id)
    |> Repo.preload(:published_version)
  end

  def create_agent(tenant_id, attrs, actor) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put(:tenant_id, tenant_id)
      |> Map.put_new(:llm_model, Agent.default_llm_model())
      |> Map.put_new(:instructions, Agent.default_instructions())
      |> Map.put_new(:tool_policy, Agent.default_tool_policy())

    case Repo.insert(Agent.changeset(%Agent{}, attrs)) do
      {:ok, agent} ->
        Audit.log(tenant_id, actor.id, "agent.create", "agent", agent.id, attrs, %{})
        {:ok, agent}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def update_agent(%Agent{} = agent, attrs, actor) do
    case Repo.update(Agent.changeset(agent, attrs)) do
      {:ok, agent} ->
        Audit.log(agent.tenant_id, actor.id, "agent.update", "agent", agent.id, attrs, %{})
        {:ok, agent}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  def archive_agent(%Agent{} = agent, actor) do
    update_agent(agent, %{status: "archived"}, actor)
  end

  def publish_agent(%Agent{} = agent, actor) do
    config = Compiler.compile(agent)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:next_version, fn repo, _ ->
        version =
          from(v in AgentVersion,
            where: v.agent_id == ^agent.id,
            select: max(v.version)
          )
          |> repo.one()
          |> case do
            nil -> 1
            value -> value + 1
          end

        {:ok, version}
      end)
      |> Ecto.Multi.insert(:version, fn %{next_version: version} ->
        AgentVersion.changeset(%AgentVersion{}, %{
          agent_id: agent.id,
          version: version,
          config: config,
          published_at: DateTime.utc_now()
        })
      end)
      |> Ecto.Multi.update(:agent, fn %{version: version} ->
        Agent.changeset(agent, %{status: "active", published_version_id: version.id})
      end)
      |> Ecto.Multi.run(:audit, fn _repo, %{version: version} ->
        Audit.log(
          agent.tenant_id,
          actor.id,
          "agent.publish",
          "agent_version",
          version.id,
          %{},
          %{}
        )

        {:ok, :logged}
      end)

    case Repo.transaction(multi) do
      {:ok, %{agent: agent, version: version}} -> {:ok, agent, version}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def list_agent_integrations(agent_id) do
    from(ai in AgentIntegration, where: ai.agent_id == ^agent_id, preload: [:integration])
    |> Repo.all()
  end

  def list_agent_channels(agent_id) do
    from(ac in AgentChannel, where: ac.agent_id == ^agent_id, preload: [:channel])
    |> Repo.all()
  end

  def list_agent_channels_for_channels(_tenant_id, []), do: []

  def list_agent_channels_for_channels(tenant_id, channel_ids) do
    from(ac in AgentChannel,
      join: a in Agent,
      on: a.id == ac.agent_id,
      where: a.tenant_id == ^tenant_id,
      where: ac.channel_id in ^channel_ids,
      select: {ac.agent_id, ac.channel_id, ac.enabled}
    )
    |> Repo.all()
  end

  def list_agent_integrations_for_integrations(_tenant_id, []), do: []

  def list_agent_integrations_for_integrations(tenant_id, integration_ids) do
    from(ai in AgentIntegration,
      join: a in Agent,
      on: a.id == ai.agent_id,
      where: a.tenant_id == ^tenant_id,
      where: ai.integration_id in ^integration_ids,
      select: {ai.agent_id, ai.integration_id, ai.enabled}
    )
    |> Repo.all()
  end

  def list_agent_webhooks_for_webhooks(_tenant_id, []), do: []

  def list_agent_webhooks_for_webhooks(tenant_id, webhook_ids) do
    from(aw in AgentWebhook,
      join: a in Agent,
      on: a.id == aw.agent_id,
      where: a.tenant_id == ^tenant_id,
      where: aw.webhook_id in ^webhook_ids,
      select: {aw.agent_id, aw.webhook_id, aw.enabled}
    )
    |> Repo.all()
  end

  def list_agent_webhooks(agent_id) do
    from(aw in AgentWebhook, where: aw.agent_id == ^agent_id, preload: [:webhook])
    |> Repo.all()
  end

  def list_agent_versions(agent_id) do
    from(v in AgentVersion, where: v.agent_id == ^agent_id, order_by: [desc: v.version])
    |> Repo.all()
  end

  def upsert_agent_integration(agent_id, integration_id, enabled) do
    attrs = %{agent_id: agent_id, integration_id: integration_id, enabled: enabled}

    %AgentIntegration{}
    |> AgentIntegration.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [enabled: enabled, updated_at: DateTime.utc_now()]],
      conflict_target: [:agent_id, :integration_id]
    )
  end

  def upsert_agent_webhook(agent_id, webhook_id, enabled) do
    attrs = %{agent_id: agent_id, webhook_id: webhook_id, enabled: enabled}

    %AgentWebhook{}
    |> AgentWebhook.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [enabled: enabled, updated_at: DateTime.utc_now()]],
      conflict_target: [:agent_id, :webhook_id]
    )
  end

  def upsert_agent_channel(agent_id, channel_id, enabled) do
    attrs = %{agent_id: agent_id, channel_id: channel_id, enabled: enabled}

    %AgentChannel{}
    |> AgentChannel.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [enabled: enabled, updated_at: DateTime.utc_now()]],
      conflict_target: [:agent_id, :channel_id]
    )
  end

  def authorize_agent_channel(agent_id, channel_id, endpoint_id \\ nil) do
    case Repo.get_by(AgentChannel, agent_id: agent_id, channel_id: channel_id) do
      nil ->
        {:error, :agent_channel_disabled}

      %AgentChannel{enabled: false} ->
        {:error, :agent_channel_disabled}

      %AgentChannel{enabled: true, scope: scope} ->
        if scope_allows_endpoint?(scope, endpoint_id),
          do: :ok,
          else: {:error, :agent_channel_scope_denied}
    end
  end

  defp scope_allows_endpoint?(scope, endpoint_id) do
    normalized = normalize_scope(scope)

    case normalized["mode"] do
      "selected" ->
        endpoint_id && to_string(endpoint_id) in normalized["endpoint_ids"]

      _ ->
        true
    end
  end

  defp normalize_scope(nil), do: %{"mode" => "all", "endpoint_ids" => []}

  defp normalize_scope(scope) when is_map(scope) do
    mode = Map.get(scope, "mode") || Map.get(scope, :mode) || "all"
    endpoint_ids = Map.get(scope, "endpoint_ids") || Map.get(scope, :endpoint_ids) || []

    %{
      "mode" => to_string(mode),
      "endpoint_ids" => endpoint_ids |> List.wrap() |> Enum.map(&to_string/1)
    }
  end

  defp normalize_scope(_scope), do: %{"mode" => "all", "endpoint_ids" => []}
end
