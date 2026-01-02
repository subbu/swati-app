defmodule Swati.Agents do
  import Ecto.Query, warn: false

  alias Swati.Audit
  alias Swati.Repo
  alias Swati.Tenancy

  alias Swati.Agents.{Agent, AgentIntegration, AgentVersion, Compiler}

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
      |> Map.put_new(:prompt_blocks, Agent.default_prompt_blocks())
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
end
