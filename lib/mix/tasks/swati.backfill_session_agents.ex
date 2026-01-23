defmodule Mix.Tasks.Swati.BackfillSessionAgents do
  use Mix.Task

  import Ecto.Query, warn: false

  alias Swati.Agents
  alias Swati.Channels.Endpoint
  alias Swati.Cases.Case
  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.Session

  @shortdoc "Backfill sessions.agent_id from routing rules"

  @moduledoc """
  Backfill session records missing agent_id.

  Agent selection order:
    - case.assigned_agent_id
    - endpoint.routing_policy default_agent_id
    - fallback active published agent per tenant

  Options:
    --tenant-id
    --dry-run

  Examples:
    MIX_ENV=prod mix swati.backfill_session_agents --tenant-id <tenant-uuid>
    MIX_ENV=prod mix swati.backfill_session_agents --dry-run
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        switches: [
          tenant_id: :string,
          dry_run: :boolean
        ]
      )

    tenant_id = Keyword.get(opts, :tenant_id)
    dry_run = Keyword.get(opts, :dry_run, false)

    sessions =
      Session
      |> where([s], is_nil(s.agent_id))
      |> maybe_filter_tenant(tenant_id)
      |> preload([:case, :endpoint])
      |> Repo.all()

    fallback_by_tenant =
      sessions
      |> Enum.map(& &1.tenant_id)
      |> Enum.uniq()
      |> Map.new(fn id -> {id, fallback_agent_id(id)} end)

    {updated, skipped} =
      Enum.reduce(sessions, {0, 0}, fn session, {updated, skipped} ->
        agent_id =
          case session.case do
            %Case{assigned_agent_id: assigned_agent_id} when not is_nil(assigned_agent_id) ->
              assigned_agent_id

            _ ->
              endpoint_default_agent_id(session.endpoint) ||
                Map.get(fallback_by_tenant, session.tenant_id)
          end

        cond do
          is_nil(agent_id) ->
            {updated, skipped + 1}

          dry_run ->
            Mix.shell().info("dry-run session=#{session.id} agent_id=#{agent_id}")
            {updated + 1, skipped}

          true ->
            case Sessions.update_session(session, %{agent_id: agent_id}) do
              {:ok, _record} ->
                {updated + 1, skipped}

              {:error, changeset} ->
                Mix.shell().error(
                  "failed session=#{session.id} errors=#{inspect(changeset.errors)}"
                )

                {updated, skipped + 1}
            end
        end
      end)

    Mix.shell().info("sessions updated=#{updated} skipped=#{skipped}")
  end

  defp maybe_filter_tenant(query, nil), do: query
  defp maybe_filter_tenant(query, ""), do: query
  defp maybe_filter_tenant(query, tenant_id), do: where(query, [s], s.tenant_id == ^tenant_id)

  defp endpoint_default_agent_id(%Endpoint{routing_policy: routing_policy})
       when is_map(routing_policy) do
    Map.get(routing_policy, "default_agent_id") || Map.get(routing_policy, :default_agent_id)
  end

  defp endpoint_default_agent_id(_endpoint), do: nil

  defp fallback_agent_id(tenant_id) do
    tenant_id
    |> Agents.list_agents()
    |> Enum.find(&(&1.status == "active" and &1.published_version_id))
    |> case do
      nil -> nil
      agent -> agent.id
    end
  end
end
