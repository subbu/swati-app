defmodule Swati.Cases.Queries do
  import Ecto.Query, warn: false

  alias Swati.Cases.Case
  alias Swati.Repo
  alias Swati.Tenancy

  def list_cases(tenant_id, filters \\ %{}) do
    Case
    |> Tenancy.scope(tenant_id)
    |> apply_filters(filters)
    |> apply_sort(filters)
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

  defp apply_filters(query, filters) do
    query
    |> maybe_filter_search(filters)
    |> maybe_filter(:status, filters)
    |> maybe_filter(:assigned_agent_id, filters)
    |> maybe_filter(:customer_id, filters)
  end

  defp apply_sort(query, filters) do
    {column, direction} = normalize_sort(filters)

    from(case_record in query, order_by: [{^direction, field(case_record, ^column)}])
  end

  defp normalize_sort(filters) do
    sort = Map.get(filters, :sort) || Map.get(filters, "sort") || %{}
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      case column do
        "updated_at" -> :updated_at
        "priority" -> :priority
        "status" -> :status
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

      from(case_record in query,
        left_join: customer in assoc(case_record, :customer),
        where:
          ilike(case_record.title, ^like) or
            ilike(case_record.category, ^like) or
            ilike(case_record.summary, ^like) or
            ilike(customer.name, ^like) or
            ilike(customer.primary_email, ^like) or
            ilike(customer.primary_phone, ^like)
      )
    end
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
