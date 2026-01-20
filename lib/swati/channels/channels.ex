defmodule Swati.Channels do
  alias Swati.Channels.Channel
  alias Swati.Channels.Commands
  alias Swati.Channels.Endpoint
  alias Swati.Channels.Queries

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

  def update_channel(%Channel{} = channel, attrs) do
    Commands.update_channel(channel, attrs)
  end

  def ensure_voice_channel(tenant_id) do
    Commands.ensure_voice_channel(tenant_id)
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

  def get_endpoint_by_channel_type(channel_type, address) do
    Queries.get_endpoint_by_channel_type(channel_type, address)
  end

  def get_endpoint_by_phone_number_id(tenant_id, phone_number_id) do
    Queries.get_endpoint_by_phone_number_id(tenant_id, phone_number_id)
  end

  def ensure_endpoint_for_phone_number(phone_number) do
    Commands.ensure_endpoint_for_phone_number(phone_number)
  end

  def update_endpoint_routing(%Endpoint{} = endpoint, routing_policy) do
    Commands.update_endpoint_routing(endpoint, routing_policy)
  end

  def list_channel_integration_ids(channel_id) do
    Queries.list_channel_integration_ids(channel_id)
  end

  def list_channel_webhook_ids(channel_id) do
    Queries.list_channel_webhook_ids(channel_id)
  end
end
