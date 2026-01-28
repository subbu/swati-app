defmodule Swati.Telephony do
  alias Swati.Telephony.Commands
  alias Swati.Telephony.PhoneNumber
  alias Swati.Telephony.Queries

  def list_phone_numbers(tenant_id) do
    Queries.list_phone_numbers(tenant_id)
  end

  def list_phone_numbers(tenant_id, filters) when is_map(filters) do
    Queries.list_phone_numbers(tenant_id, filters)
  end

  def count_phone_numbers(tenant_id) do
    Queries.count_phone_numbers(tenant_id)
  end

  def get_phone_number!(tenant_id, id) do
    Queries.get_phone_number!(tenant_id, id)
  end

  def get_phone_number!(id) do
    Queries.get_phone_number!(id)
  end

  def get_phone_number_by_e164!(e164) when is_binary(e164) do
    Queries.get_phone_number_by_e164!(e164)
  end

  def search_available_numbers(params, provider \\ :plivo) when is_map(params) do
    Commands.search_available_numbers(params, provider)
  end

  def provision_phone_number(tenant_id, attrs, actor) do
    Commands.provision_phone_number(tenant_id, attrs, actor)
  end

  def assign_inbound_agent(%PhoneNumber{} = phone_number, agent_id, actor) do
    Commands.assign_inbound_agent(phone_number, agent_id, actor)
  end

  def activate_phone_number(%PhoneNumber{} = phone_number, actor) do
    Commands.activate_phone_number(phone_number, actor)
  end

  def suspend_phone_number(%PhoneNumber{} = phone_number, actor) do
    Commands.suspend_phone_number(phone_number, actor)
  end
end
