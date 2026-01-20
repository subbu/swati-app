defmodule Swati.Trust.Queries do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionEvent
  alias Swati.Cases.Case
  alias Swati.Tenancy

  def list_recent_cases(tenant_id, limit) do
    Case
    |> Tenancy.scope(tenant_id)
    |> order_by([c], desc: c.updated_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_case_events(tenant_id, case_id) do
    from(e in SessionEvent,
      join: s in Session,
      on: s.id == e.session_id,
      where: s.tenant_id == ^tenant_id and s.case_id == ^case_id,
      order_by: [asc: e.ts],
      select: %{
        id: e.id,
        ts: e.ts,
        type: e.type,
        category: e.category,
        payload: e.payload,
        session_id: s.id,
        session_external_id: s.external_id
      }
    )
    |> Repo.all()
  end

  def list_tool_results(tenant_id, since) do
    from(e in SessionEvent,
      join: s in Session,
      on: s.id == e.session_id,
      where: s.tenant_id == ^tenant_id and e.type == "tool.result" and e.ts >= ^since,
      select: %{
        ts: e.ts,
        payload: e.payload
      }
    )
    |> Repo.all()
  end
end
