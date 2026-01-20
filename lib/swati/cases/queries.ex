defmodule Swati.Cases.Queries do
  import Ecto.Query, warn: false

  alias Swati.Cases.Case
  alias Swati.Repo
  alias Swati.Tenancy

  def list_cases(tenant_id, filters \\ %{}) do
    Case
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:status, filters)
    |> maybe_filter(:assigned_agent_id, filters)
    |> maybe_filter(:customer_id, filters)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  def get_case!(tenant_id, case_id) do
    Case
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(case_id)
  end

  def find_open_case_for_customer(tenant_id, customer_id, category \\ nil) do
    Case
    |> Tenancy.scope(tenant_id)
    |> where([c], c.customer_id == ^customer_id)
    |> where([c], c.status in [:new, :triage, :in_progress, :waiting_on_customer])
    |> maybe_filter_category(category)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp maybe_filter_category(query, nil), do: query
  defp maybe_filter_category(query, ""), do: query

  defp maybe_filter_category(query, category) do
    from(c in query, where: c.category == ^category)
  end

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end
end
