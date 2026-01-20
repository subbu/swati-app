defmodule Swati.Cases do
  alias Swati.Cases.Case
  alias Swati.Cases.Commands
  alias Swati.Cases.Memory
  alias Swati.Cases.Queries

  def list_cases(tenant_id, filters \\ %{}) do
    Queries.list_cases(tenant_id, filters)
  end

  def get_case!(tenant_id, case_id) do
    Queries.get_case!(tenant_id, case_id)
  end

  def find_open_case_for_customer(tenant_id, customer_id, category \\ nil) do
    Queries.find_open_case_for_customer(tenant_id, customer_id, category)
  end

  def create_case(tenant_id, attrs) do
    Commands.create_case(tenant_id, attrs)
  end

  def update_case(%Case{} = case_record, attrs) do
    Commands.update_case(case_record, attrs)
  end

  def set_case_status(%Case{} = case_record, status) do
    Commands.set_case_status(case_record, status)
  end

  def update_memory(%Case{} = case_record, events) do
    memory = Memory.update_from_events(case_record.memory, events)
    Commands.update_case(case_record, %{memory: memory})
  end
end
