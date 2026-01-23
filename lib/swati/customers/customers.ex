defmodule Swati.Customers do
  alias Swati.Customers.Commands
  alias Swati.Customers.Customer
  alias Swati.Customers.Queries

  def list_customers(tenant_id, filters \\ %{}) do
    Queries.list_customers(tenant_id, filters)
  end

  def list_customers_paginated(tenant_id, filters \\ %{}, flop_params \\ %{}) do
    Queries.list_customers_paginated(tenant_id, filters, flop_params)
  end

  def get_customer!(tenant_id, customer_id) do
    Queries.get_customer!(tenant_id, customer_id)
  end

  def create_customer(tenant_id, attrs) do
    Commands.create_customer(tenant_id, attrs)
  end

  def update_customer(%Customer{} = customer, attrs) do
    Commands.update_customer(customer, attrs)
  end

  def resolve_customer(tenant_id, channel_id, kind, attrs) do
    Commands.resolve_customer(tenant_id, channel_id, kind, attrs)
  end
end
