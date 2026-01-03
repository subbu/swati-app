defmodule Swati.Telephony.Queries do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Telephony.PhoneNumber
  alias Swati.Tenancy

  def list_phone_numbers(tenant_id) do
    PhoneNumber
    |> Tenancy.scope(tenant_id)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  def list_phone_numbers(tenant_id, filters) when is_map(filters) do
    filters = normalize_filters(filters)

    PhoneNumber
    |> Tenancy.scope(tenant_id)
    |> apply_search_filter(filters)
    |> apply_status_filter(filters)
    |> apply_agent_filter(filters)
    |> apply_provider_filter(filters)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  def get_phone_number!(tenant_id, id) do
    Repo.get_by!(PhoneNumber, id: id, tenant_id: tenant_id)
  end

  def get_phone_number!(id), do: Repo.get!(PhoneNumber, id)

  defp normalize_filters(filters) do
    filters
    |> Enum.map(fn {key, value} -> {to_string(key), value} end)
    |> Map.new()
  end

  defp apply_search_filter(query, %{"query" => query_value}) when is_binary(query_value) do
    trimmed = String.trim(query_value)

    if trimmed == "" do
      query
    else
      like = "%#{trimmed}%"

      from(number in query,
        where:
          ilike(number.e164, ^like) or ilike(number.country, ^like) or
            ilike(number.region, ^like)
      )
    end
  end

  defp apply_search_filter(query, _filters), do: query

  defp apply_status_filter(query, %{"status" => status}) when is_binary(status) do
    if status == "" do
      query
    else
      from(number in query, where: number.status == ^status)
    end
  end

  defp apply_status_filter(query, _filters), do: query

  defp apply_agent_filter(query, %{"agent_id" => agent_id}) when is_binary(agent_id) do
    if agent_id == "" do
      query
    else
      from(number in query, where: number.inbound_agent_id == ^agent_id)
    end
  end

  defp apply_agent_filter(query, _filters), do: query

  defp apply_provider_filter(query, %{"provider" => provider}) when is_binary(provider) do
    if provider == "" do
      query
    else
      from(number in query, where: number.provider == ^provider)
    end
  end

  defp apply_provider_filter(query, _filters), do: query
end
