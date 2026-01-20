defmodule Swati.Sessions.Queries do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionEvent
  alias Swati.Tenancy

  def list_sessions(tenant_id, filters \\ %{}) do
    Session
    |> Tenancy.scope(tenant_id)
    |> maybe_filter(:status, filters)
    |> maybe_filter(:channel_id, filters)
    |> maybe_filter(:endpoint_id, filters)
    |> maybe_filter(:case_id, filters)
    |> maybe_filter(:customer_id, filters)
    |> order_by([s], desc: s.inserted_at)
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

  defp maybe_filter(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      from(record in query, where: field(record, ^key) == ^value)
    end
  end
end
