defmodule Swati.Sessions.Commands do
  alias Swati.Repo
  alias Swati.Sessions.Session

  def create_session(tenant_id, attrs) do
    attrs = stringify_keys(attrs)
    started_at = Map.get(attrs, "started_at")

    attrs =
      attrs
      |> Map.put("tenant_id", tenant_id)
      |> maybe_put_started_at(started_at)

    %Session{}
    |> Session.changeset(attrs)
    |> Repo.insert()
  end

  def update_session(%Session{} = session, attrs) do
    attrs = stringify_keys(attrs)

    session
    |> Session.changeset(attrs)
    |> Repo.update()
  end

  def set_session_end(%Session{} = session, ended_at, status) do
    attrs = %{
      ended_at: ended_at,
      status: status
    }

    update_session(session, attrs)
  end

  def touch_last_event(%Session{} = session, last_event_at) do
    update_session(session, %{last_event_at: last_event_at})
  end

  defp maybe_put_started_at(attrs, nil) do
    Map.put(attrs, "started_at", DateTime.utc_now())
  end

  defp maybe_put_started_at(attrs, started_at), do: Map.put(attrs, "started_at", started_at)

  defp stringify_keys(attrs) do
    Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
  end
end
