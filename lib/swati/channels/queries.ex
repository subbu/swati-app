defmodule Swati.Channels.Queries do
  import Ecto.Query, warn: false

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
