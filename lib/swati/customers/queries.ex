defmodule Swati.Customers.Queries do
  import Ecto.Query, warn: false

  alias Swati.Customers.Customer
  alias Swati.Customers.CustomerIdentity
  alias Swati.Repo
  alias Swati.Tenancy

  def list_customers(tenant_id, filters \\ %{}) do
    Customer
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:status, filters)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  def get_customer!(tenant_id, customer_id) do
    Customer
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(customer_id)
  end

  def get_identity_by_external_id(tenant_id, channel_id, external_id)
      when is_binary(external_id) do
    CustomerIdentity
    |> Tenancy.scope(tenant_id)
    |> where([i], i.channel_id == ^channel_id)
    |> where([i], i.external_id == ^external_id)
    |> Repo.one()
  end

  def get_identity_by_address(tenant_id, channel_id, address) when is_binary(address) do
    CustomerIdentity
    |> Tenancy.scope(tenant_id)
    |> where([i], i.channel_id == ^channel_id)
    |> where([i], i.address == ^address)
    |> Repo.one()
  end

  def get_identity_by_external_id_any_channel(tenant_id, external_id)
      when is_binary(external_id) do
    CustomerIdentity
    |> Tenancy.scope(tenant_id)
    |> where([i], i.external_id == ^external_id)
    |> order_by([i], desc: i.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def get_identity_by_address_any_channel(tenant_id, kind, address) when is_binary(address) do
    CustomerIdentity
    |> Tenancy.scope(tenant_id)
    |> maybe_filter_kind(kind)
    |> where([i], i.address == ^address)
    |> order_by([i], desc: i.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end

  defp maybe_filter_kind(query, nil), do: query
  defp maybe_filter_kind(query, ""), do: query

  defp maybe_filter_kind(query, kind) do
    from(identity in query, where: identity.kind == ^kind)
  end
end
