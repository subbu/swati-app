defmodule Swati.Channels do
  alias Swati.Channels.Channel
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Commands
  alias Swati.Channels.Endpoint
  alias Swati.Channels.Gmail
  alias Swati.Channels.Imap
  alias Swati.Channels.Outlook
  alias Swati.Channels.Queries
  alias Oban
  alias Swati.Repo

  @sync_providers [:gmail, :outlook, :imap]

  def sync_providers, do: @sync_providers

  def sync_interval_seconds do
    Application.get_env(:swati, :channel_sync_interval_seconds, 300)
  end

  def list_channels(tenant_id) do
    Queries.list_channels(tenant_id)
  end

  def get_channel!(tenant_id, channel_id) do
    Queries.get_channel!(tenant_id, channel_id)
  end

  def get_channel_by_key(tenant_id, key) do
    Queries.get_channel_by_key(tenant_id, key)
  end

  def create_channel(tenant_id, attrs) do
    Commands.create_channel(tenant_id, attrs)
  end

  def ensure_channel(tenant_id, attrs) do
    Commands.ensure_channel(tenant_id, attrs)
  end

  def update_channel(%Channel{} = channel, attrs) do
    Commands.update_channel(channel, attrs)
  end

  def ensure_voice_channel(tenant_id) do
    Commands.ensure_voice_channel(tenant_id)
  end

  def ensure_email_channel(tenant_id) do
    Commands.ensure_email_channel(tenant_id)
  end

  def list_endpoints(tenant_id, filters \\ %{}) do
    Queries.list_endpoints(tenant_id, filters)
  end

  def get_endpoint!(tenant_id, endpoint_id) do
    Queries.get_endpoint!(tenant_id, endpoint_id)
  end

  def get_endpoint_by_address(tenant_id, channel_id, address) do
    Queries.get_endpoint_by_address(tenant_id, channel_id, address)
  end

  def get_endpoint_by_channel_key(channel_key, address) do
    Queries.get_endpoint_by_channel_key(channel_key, address)
  end

  def get_endpoint_by_channel_key_any_status(channel_key, address) do
    Queries.get_endpoint_by_channel_key_any_status(channel_key, address)
  end

  def get_endpoint_by_channel_type(channel_type, address) do
    Queries.get_endpoint_by_channel_type(channel_type, address)
  end

  def get_endpoint_by_channel_type_any_status(channel_type, address) do
    Queries.get_endpoint_by_channel_type_any_status(channel_type, address)
  end

  def get_endpoint_by_phone_number_id(tenant_id, phone_number_id) do
    Queries.get_endpoint_by_phone_number_id(tenant_id, phone_number_id)
  end

  def ensure_endpoint_for_phone_number(phone_number) do
    Commands.ensure_endpoint_for_phone_number(phone_number)
  end

  def ensure_endpoint(tenant_id, channel_id, address, attrs \\ %{}) do
    Commands.ensure_endpoint(tenant_id, channel_id, address, attrs)
  end

  def update_endpoint_routing(%Endpoint{} = endpoint, routing_policy) do
    Commands.update_endpoint_routing(endpoint, routing_policy)
  end

  def ensure_endpoint_for_email(tenant_id, address, attrs \\ %{}) do
    Commands.ensure_endpoint_for_email(tenant_id, address, attrs)
  end

  def list_connections(tenant_id, filters \\ %{}) do
    Queries.list_connections(tenant_id, filters)
  end

  def list_syncable_connections(cutoff \\ nil) do
    Queries.list_syncable_connections(sync_providers(), cutoff)
  end

  def get_connection!(tenant_id, connection_id) do
    Queries.get_connection!(tenant_id, connection_id)
  end

  def get_connection_by_endpoint(tenant_id, endpoint_id) do
    Queries.get_connection_by_endpoint(tenant_id, endpoint_id)
  end

  def create_connection(tenant_id, attrs) do
    Commands.create_connection(tenant_id, attrs)
  end

  def update_connection(connection, attrs) do
    Commands.update_connection(connection, attrs)
  end

  def sync_connection(tenant_id, connection_id) do
    connection =
      tenant_id
      |> get_connection!(connection_id)
      |> Repo.preload([:channel, :endpoint])

    sync_connection(connection)
  end

  def sync_connection(%ChannelConnection{} = connection) do
    connection = Repo.preload(connection, [:channel, :endpoint])

    case connection.provider do
      :gmail -> Gmail.sync_connection(connection)
      :outlook -> Outlook.sync_connection(connection)
      :imap -> Imap.sync_connection(connection)
      _ -> {:error, :provider_not_supported}
    end
  end

  def send_message(%ChannelConnection{} = connection, attrs) when is_map(attrs) do
    connection = Repo.preload(connection, [:channel, :endpoint])

    case connection.provider do
      :gmail -> Gmail.send_message(connection, attrs)
      :outlook -> Outlook.send_message(connection, attrs)
      :imap -> Imap.send_message(connection, attrs)
      _ -> {:error, :provider_not_supported}
    end
  end

  def connect_imap(tenant_id, attrs, opts \\ []) do
    Imap.connect(tenant_id, attrs, opts)
  end

  def enqueue_sync_connection(tenant_id, connection_id) do
    %{"tenant_id" => tenant_id, "connection_id" => connection_id}
    |> Swati.Workers.SyncChannelConnection.new()
    |> Oban.insert()
  end

  def enqueue_sync_connection(%ChannelConnection{} = connection) do
    %{"tenant_id" => connection.tenant_id, "connection_id" => connection.id}
    |> Swati.Workers.SyncChannelConnection.new()
    |> Oban.insert()
  end

  def list_channel_integration_ids(channel_id) do
    Queries.list_channel_integration_ids(channel_id)
  end

  def list_channel_webhook_ids(channel_id) do
    Queries.list_channel_webhook_ids(channel_id)
  end

  def channel_health_map(tenant_id) do
    Queries.channel_health_map(tenant_id)
  end

  def channel_connections_by_endpoint(tenant_id, channel_id) do
    Queries.channel_connections_by_endpoint(tenant_id, channel_id)
  end
end
