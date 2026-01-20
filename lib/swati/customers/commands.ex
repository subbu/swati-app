defmodule Swati.Customers.Commands do
  alias Swati.Customers.Customer
  alias Swati.Customers.CustomerIdentity
  alias Swati.Customers.Queries
  alias Swati.Repo

  def create_customer(tenant_id, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", tenant_id)

    %Customer{}
    |> Customer.changeset(attrs)
    |> Repo.insert()
  end

  def update_customer(%Customer{} = customer, attrs) do
    customer
    |> Customer.changeset(attrs)
    |> Repo.update()
  end

  def create_identity(%Customer{} = customer, attrs) do
    attrs =
      attrs
      |> stringify_keys()
      |> Map.put("tenant_id", customer.tenant_id)
      |> Map.put("customer_id", customer.id)

    %CustomerIdentity{}
    |> CustomerIdentity.changeset(attrs)
    |> Repo.insert()
  end

  def resolve_customer(tenant_id, channel_id, kind, attrs) do
    external_id = Map.get(attrs, :external_id) || Map.get(attrs, "external_id")
    address = Map.get(attrs, :address) || Map.get(attrs, "address")

    identity =
      cond do
        is_binary(external_id) and external_id != "" ->
          Queries.get_identity_by_external_id(tenant_id, channel_id, external_id)

        is_binary(address) and address != "" ->
          Queries.get_identity_by_address(tenant_id, channel_id, address)

        true ->
          nil
      end

    case identity do
      %CustomerIdentity{} = identity ->
        customer = Repo.get!(Customer, identity.customer_id)
        {:ok, customer, identity}

      nil ->
        create_customer_and_identity(tenant_id, channel_id, kind, attrs)
    end
  end

  defp create_customer_and_identity(tenant_id, channel_id, kind, attrs) do
    Repo.transaction(fn ->
      customer_attrs = build_customer_attrs(attrs, kind)
      {:ok, customer} = create_customer(tenant_id, customer_attrs)

      identity_attrs = build_identity_attrs(attrs, channel_id, kind)
      {:ok, identity} = create_identity(customer, identity_attrs)

      {customer, identity}
    end)
    |> case do
      {:ok, {customer, identity}} -> {:ok, customer, identity}
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_customer_attrs(attrs, kind) do
    name = Map.get(attrs, :name) || Map.get(attrs, "name")
    timezone = Map.get(attrs, :timezone) || Map.get(attrs, "timezone")
    language = Map.get(attrs, :language) || Map.get(attrs, "language")

    base = %{
      "name" => name,
      "timezone" => timezone,
      "language" => language,
      "preferences" => Map.get(attrs, :preferences) || Map.get(attrs, "preferences") || %{},
      "metadata" => Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{}
    }

    case kind do
      :email ->
        Map.put(base, "primary_email", Map.get(attrs, :address) || Map.get(attrs, "address"))

      :phone ->
        Map.put(base, "primary_phone", Map.get(attrs, :address) || Map.get(attrs, "address"))

      _ ->
        base
    end
  end

  defp build_identity_attrs(attrs, channel_id, kind) do
    %{
      "channel_id" => channel_id,
      "kind" => kind,
      "external_id" => Map.get(attrs, :external_id) || Map.get(attrs, "external_id"),
      "address" => Map.get(attrs, :address) || Map.get(attrs, "address"),
      "metadata" =>
        Map.get(attrs, :identity_metadata) || Map.get(attrs, "identity_metadata") || %{}
    }
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
