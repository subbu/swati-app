defmodule Swati.Channels.Queries do
  import Ecto.Query, warn: false

  alias Swati.Agents.Agent
  alias Swati.Agents.AgentChannel
  alias Swati.Channels.Channel
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.ChannelIntegration
  alias Swati.Channels.ChannelWebhook
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Tenancy

  def list_channels(tenant_id) do
    Channel
    |> Tenancy.scope(tenant_id)
    |> order_by([c], asc: c.name)
    |> Repo.all()
  end

  def list_connections(tenant_id, filters \\ %{}) do
    ChannelConnection
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:channel_id, filters)
    |> maybe_filter(:provider, filters)
    |> maybe_filter(:status, filters)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def list_syncable_connections(providers, cutoff \\ nil) when is_list(providers) do
    ChannelConnection
    |> where([c], c.provider in ^providers)
    |> where([c], c.status in [:active, :error])
    |> maybe_filter_sync_cutoff(cutoff)
    |> Repo.all()
  end

  def get_connection!(tenant_id, connection_id) do
    ChannelConnection
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(connection_id)
  end

  def get_connection_by_endpoint(tenant_id, endpoint_id) do
    ChannelConnection
    |> Tenancy.scope(tenant_id)
    |> where([c], c.endpoint_id == ^endpoint_id)
    |> Repo.one()
  end

  def get_channel!(tenant_id, channel_id) do
    Channel
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(channel_id)
  end

  def get_channel_by_key(tenant_id, key) when is_binary(key) do
    Channel
    |> Tenancy.scope(tenant_id)
    |> where([c], c.key == ^key)
    |> Repo.one()
  end

  def list_endpoints(tenant_id, filters \\ %{}) do
    Endpoint
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:channel_id, filters)
    |> maybe_filter(:status, filters)
    |> order_by([e], asc: e.address)
    |> Repo.all()
  end

  def get_endpoint!(tenant_id, endpoint_id) do
    Endpoint
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(endpoint_id)
  end

  def get_endpoint_by_address(tenant_id, channel_id, address)
      when is_binary(address) do
    Endpoint
    |> Tenancy.scope(tenant_id)
    |> where([e], e.channel_id == ^channel_id)
    |> where([e], e.address == ^address)
    |> Repo.one()
  end

  def get_endpoint_by_channel_key(channel_key, address)
      when is_binary(channel_key) and is_binary(address) do
    Endpoint
    |> join(:inner, [e], c in Channel, on: c.id == e.channel_id)
    |> where([e, c], c.key == ^channel_key)
    |> where([e, c], c.status == :active)
    |> where([e, _c], e.address == ^address)
    |> where([e, _c], e.status == :active)
    |> preload([e, c], channel: c)
    |> Repo.one()
  end

  def get_endpoint_by_channel_key_any_status(channel_key, address)
      when is_binary(channel_key) and is_binary(address) do
    Endpoint
    |> join(:inner, [e], c in Channel, on: c.id == e.channel_id)
    |> where([e, c], c.key == ^channel_key)
    |> where([e, _c], e.address == ^address)
    |> preload([e, c], channel: c)
    |> Repo.one()
  end

  def get_endpoint_by_channel_type(channel_type, address)
      when is_binary(channel_type) and is_binary(address) do
    type =
      case channel_type do
        "voice" -> :voice
        "email" -> :email
        "chat" -> :chat
        "whatsapp" -> :whatsapp
        "custom" -> :custom
        _ -> nil
      end

    if is_nil(type) do
      nil
    else
      Endpoint
      |> join(:inner, [e], c in Channel, on: c.id == e.channel_id)
      |> where([e, c], c.type == ^type)
      |> where([e, c], c.status == :active)
      |> where([e, _c], e.address == ^address)
      |> where([e, _c], e.status == :active)
      |> preload([e, c], channel: c)
      |> Repo.one()
    end
  end

  def get_endpoint_by_channel_type_any_status(channel_type, address)
      when is_binary(channel_type) and is_binary(address) do
    type =
      case channel_type do
        "voice" -> :voice
        "email" -> :email
        "chat" -> :chat
        "whatsapp" -> :whatsapp
        "custom" -> :custom
        _ -> nil
      end

    if is_nil(type) do
      nil
    else
      Endpoint
      |> join(:inner, [e], c in Channel, on: c.id == e.channel_id)
      |> where([e, c], c.type == ^type)
      |> where([e, _c], e.address == ^address)
      |> preload([e, c], channel: c)
      |> Repo.one()
    end
  end

  def get_endpoint_by_phone_number_id(tenant_id, phone_number_id) do
    Endpoint
    |> Tenancy.scope(tenant_id)
    |> where([e], e.phone_number_id == ^phone_number_id)
    |> Repo.one()
  end

  def list_channel_integration_ids(channel_id) do
    ChannelIntegration
    |> where([ci], ci.channel_id == ^channel_id)
    |> where([ci], ci.enabled == true)
    |> select([ci], ci.integration_id)
    |> Repo.all()
  end

  def list_channel_webhook_ids(channel_id) do
    ChannelWebhook
    |> where([cw], cw.channel_id == ^channel_id)
    |> where([cw], cw.enabled == true)
    |> select([cw], cw.webhook_id)
    |> Repo.all()
  end

  @doc """
  Returns a map of channel_id => health summary for all channels in a tenant.

  Health summary includes:
  - active_count: number of active connections
  - error_count: number of error/revoked connections
  - endpoint_count: number of unique endpoints with connections
  - last_synced_at: most recent sync timestamp across all connections
  - providers: list of unique providers (gmail, outlook, imap)
  """
  def channel_health_map(tenant_id) do
    query =
      from(c in ChannelConnection,
        where: c.tenant_id == ^tenant_id,
        group_by: c.channel_id,
        select: {
          c.channel_id,
          %{
            active_count: count(fragment("CASE WHEN ? = 'active' THEN 1 END", c.status)),
            error_count:
              count(fragment("CASE WHEN ? IN ('error', 'revoked') THEN 1 END", c.status)),
            endpoint_count: count(c.endpoint_id, :distinct),
            last_synced_at: max(c.last_synced_at),
            providers: fragment("array_agg(DISTINCT ?)", c.provider)
          }
        }
      )

    query
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns detailed connection info for a specific channel, grouped by endpoint.
  Used for the channel scope sheet.
  """
  def channel_connections_by_endpoint(tenant_id, channel_id) do
    ChannelConnection
    |> Tenancy.scope(tenant_id)
    |> where([c], c.channel_id == ^channel_id)
    |> preload(:endpoint)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
    |> Enum.group_by(& &1.endpoint_id)
  end

  @doc """
  Returns a unified view of all surfaces (channels grouped by type) for the Surfaces UI.

  Returns a list of surface maps, each containing:
  - type: :voice, :email, :chat, :whatsapp, or :custom
  - channels: list of channels of this type
  - endpoints: list of endpoints across all channels of this type
  - connections: list of connections across all channels of this type
  - agents: list of agents assigned to channels of this type with autonomy levels
  - health: aggregated health status (:healthy, :warning, :error)
  - stats: %{endpoint_count, connection_count, agent_count, last_synced_at}
  """
  def unified_surfaces_view(tenant_id) do
    channels = list_channels(tenant_id)
    endpoints = list_endpoints(tenant_id) |> Repo.preload(:channel)
    connections = list_connections(tenant_id) |> Repo.preload([:channel, :endpoint])
    health_map = channel_health_map(tenant_id)

    agent_channels =
      from(ac in AgentChannel,
        join: a in Agent,
        on: a.id == ac.agent_id,
        where: a.tenant_id == ^tenant_id,
        where: ac.enabled == true,
        select: ac,
        preload: [:agent]
      )
      |> Repo.all()

    channel_types = [:voice, :email, :chat, :whatsapp, :custom]

    Enum.map(channel_types, fn type ->
      type_channels = Enum.filter(channels, &(&1.type == type))
      type_channel_ids = Enum.map(type_channels, & &1.id) |> MapSet.new()

      type_endpoints =
        Enum.filter(endpoints, fn e ->
          e.channel && MapSet.member?(type_channel_ids, e.channel.id)
        end)

      type_connections =
        Enum.filter(connections, fn c ->
          c.channel && MapSet.member?(type_channel_ids, c.channel.id)
        end)

      type_agent_channels =
        Enum.filter(agent_channels, fn ac ->
          MapSet.member?(type_channel_ids, ac.channel_id)
        end)

      type_agents =
        type_agent_channels
        |> Enum.uniq_by(& &1.agent_id)
        |> Enum.map(fn ac ->
          %{
            agent: ac.agent,
            autonomy_level: ac.autonomy_level,
            channel_id: ac.channel_id
          }
        end)

      health = compute_surface_health(type_channel_ids, health_map)

      last_synced =
        type_connections
        |> Enum.map(& &1.last_synced_at)
        |> Enum.reject(&is_nil/1)
        |> Enum.max_by(&DateTime.to_unix/1, fn -> nil end)

      %{
        type: type,
        channels: type_channels,
        endpoints: type_endpoints,
        connections: type_connections,
        agents: type_agents,
        health: health,
        stats: %{
          endpoint_count: length(type_endpoints),
          connection_count: length(type_connections),
          agent_count: length(type_agents),
          last_synced_at: last_synced
        }
      }
    end)
  end

  defp compute_surface_health(channel_ids, health_map) do
    healths =
      channel_ids
      |> MapSet.to_list()
      |> Enum.map(&Map.get(health_map, &1))
      |> Enum.reject(&is_nil/1)

    cond do
      healths == [] ->
        :no_data

      Enum.any?(healths, fn h -> h.error_count > 0 end) ->
        :error

      Enum.any?(healths, fn h -> h.active_count == 0 end) ->
        :warning

      true ->
        :healthy
    end
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end

  defp maybe_filter_sync_cutoff(query, nil), do: query

  defp maybe_filter_sync_cutoff(query, %DateTime{} = cutoff) do
    from(record in query,
      where: is_nil(record.last_synced_at) or record.last_synced_at <= ^cutoff
    )
  end
end
