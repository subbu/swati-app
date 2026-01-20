defmodule Swati.Sessions.Queries do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionEvent
  alias Swati.Tenancy

  def list_sessions(tenant_id, filters \\ %{}) do
    Session
    |> Tenancy.scope(tenant_id)
    |> apply_filters(filters)
    |> apply_sort(filters)
    |> Repo.all()
  end

  def get_session!(tenant_id, session_id) do
    Session
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(session_id)
  end

  def get_session_by_external_id(tenant_id, endpoint_id, external_id)
      when is_binary(external_id) do
    Session
    |> Tenancy.scope(tenant_id)
    |> where([s], s.endpoint_id == ^endpoint_id)
    |> where([s], s.external_id == ^external_id)
    |> Repo.one()
  end

  def list_session_events(session_id) do
    SessionEvent
    |> where([e], e.session_id == ^session_id)
    |> order_by([e], asc: e.ts)
    |> Repo.all()
  end

  defp apply_filters(query, filters) do
    query
    |> maybe_filter_search(filters)
    |> maybe_filter(:status, filters)
    |> maybe_filter(:agent_id, filters)
    |> maybe_filter(:channel_id, filters)
    |> maybe_filter(:endpoint_id, filters)
    |> maybe_filter(:case_id, filters)
    |> maybe_filter(:customer_id, filters)
  end

  defp apply_sort(query, filters) do
    {column, direction} = normalize_sort(filters)

    from(session in query, order_by: [{^direction, field(session, ^column)}])
  end

  defp normalize_sort(filters) do
    sort = Map.get(filters, :sort) || Map.get(filters, "sort") || %{}
    column = Map.get(sort, :column) || Map.get(sort, "column")
    direction = Map.get(sort, :direction) || Map.get(sort, "direction")

    column =
      case column do
        "started_at" -> :started_at
        "last_event_at" -> :last_event_at
        "status" -> :status
        "direction" -> :direction
        _ -> :started_at
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

      from(session in query,
        left_join: endpoint in assoc(session, :endpoint),
        left_join: customer in assoc(session, :customer),
        where:
          ilike(session.external_id, ^like) or
            ilike(endpoint.address, ^like) or
            ilike(fragment("?->>?", session.metadata, "from_address"), ^like) or
            ilike(fragment("?->>?", session.metadata, "to_address"), ^like) or
            ilike(customer.name, ^like) or
            ilike(customer.primary_email, ^like) or
            ilike(customer.primary_phone, ^like)
      )
    end
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
