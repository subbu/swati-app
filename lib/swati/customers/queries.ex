defmodule Swati.Customers.Queries do
  import Ecto.Query, warn: false

  alias Swati.Customers.Customer
  alias Swati.Customers.CustomerIdentity
  alias Swati.Repo
  alias Swati.Tenancy

  def list_customers(tenant_id, filters \\ %{}) do
    Customer
    |> Tenancy.scope(tenant_id)
    |> apply_filters(filters)
    |> apply_sort(filters)
    |> Repo.all()
  end

  def list_customers_paginated(tenant_id, filters \\ %{}, flop_params \\ %{}) do
    Customer
    |> Tenancy.scope(tenant_id)
    |> apply_filters(filters)
    |> Flop.validate_and_run(flop_params, for: Customer)
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

  defp apply_filters(query, filters) do
    query
    |> maybe_filter_search(filters)
    |> maybe_filter(:status, filters)
  end

  defp apply_sort(query, filters) do
    {column, direction} = normalize_sort(filters)

    from(customer in query, order_by: [{^direction, field(customer, ^column)}])
  end

  defp normalize_sort(filters) do
    sort = Map.get(filters, :sort) || Map.get(filters, "sort") || %{}
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      case column do
        "name" -> :name
        "status" -> :status
        "inserted_at" -> :inserted_at
        "updated_at" -> :updated_at
        _ -> :updated_at
      end

    direction =
      case direction do
        "asc" -> :asc
        "desc" -> :desc
        _ -> :desc
      end

    {column, direction}
  end

  defp maybe_filter_search(query, filters) do
    term = Map.get(filters, :query) || Map.get(filters, "query")

    if is_nil(term) or String.trim(to_string(term)) == "" do
      query
    else
      like = "%#{String.trim(to_string(term))}%"

      from(customer in query,
        left_join: identity in assoc(customer, :identities),
        left_join: channel in assoc(identity, :channel),
        where:
          ilike(customer.name, ^like) or
            ilike(customer.primary_email, ^like) or
            ilike(customer.primary_phone, ^like) or
            ilike(identity.address, ^like) or
            ilike(identity.external_id, ^like) or
            ilike(channel.key, ^like),
        distinct: true
      )
    end
  end

  defp maybe_filter_kind(query, nil), do: query
  defp maybe_filter_kind(query, ""), do: query

  defp maybe_filter_kind(query, kind) do
    from(identity in query, where: identity.kind == ^kind)
  end
end
