defmodule Swati.Inbound.Ownership do
  alias Swati.Inbound.Commands
  alias Swati.Inbound.Queries
  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.Session

  def record_route(%Session{} = session, route, opts \\ %{}) do
    owner_agent_id = Map.get(route, :owner_agent_id) || Map.get(route, "owner_agent_id")

    if present?(owner_agent_id) do
      latest = Queries.latest_thread_ownership_event_for_session(session.tenant_id, session.id)

      cond do
        latest && latest.owner_agent_id == owner_agent_id ->
          {:ok, latest}

        true ->
          attrs = %{
            tenant_id: session.tenant_id,
            session_id: session.id,
            delivery_id: Map.get(opts, :delivery_id) || Map.get(opts, "delivery_id"),
            thread_key: thread_key(session, route),
            previous_agent_id: latest && latest.owner_agent_id,
            owner_agent_id: owner_agent_id,
            reason: Map.get(route, :route_reason) || Map.get(route, "route_reason") || "inbound",
            source: Map.get(opts, :source) || Map.get(opts, "source") || "inbound",
            metadata: Map.get(opts, :metadata) || Map.get(opts, "metadata") || %{},
            resolved_at: DateTime.utc_now()
          }

          with {:ok, event} <- Commands.create_thread_ownership_event(attrs) do
            maybe_append_session_event(session.id, event)
            {:ok, event}
          end
      end
    else
      {:error, :owner_agent_missing}
    end
  end

  def transfer_session_owner(session_id, target_agent_id, opts \\ %{}) do
    with true <- present?(target_agent_id) or {:error, :target_agent_missing},
         %Session{} = session <- Repo.get(Session, session_id) || {:error, :session_not_found} do
      if session.agent_id == target_agent_id do
        {:ok, %{session: session, ownership_event: nil}}
      else
        previous_agent_id = session.agent_id

        with {:ok, updated_session} <-
               Sessions.update_session(session, %{agent_id: target_agent_id}) do
          attrs = %{
            tenant_id: updated_session.tenant_id,
            session_id: updated_session.id,
            thread_key: updated_session.external_id || updated_session.id,
            previous_agent_id: previous_agent_id,
            owner_agent_id: target_agent_id,
            reason: Map.get(opts, :reason) || Map.get(opts, "reason") || "handoff_accepted",
            source: Map.get(opts, :source) || Map.get(opts, "source") || "handoff",
            metadata: Map.get(opts, :metadata) || Map.get(opts, "metadata") || %{},
            resolved_at: DateTime.utc_now()
          }

          with {:ok, event} <- Commands.create_thread_ownership_event(attrs) do
            maybe_append_session_event(updated_session.id, event)
            {:ok, %{session: updated_session, ownership_event: event}}
          end
        end
      end
    end
  end

  defp maybe_append_session_event(session_id, event) do
    payload = %{
      "thread_ownership_event_id" => event.id,
      "previous_agent_id" => event.previous_agent_id,
      "owner_agent_id" => event.owner_agent_id,
      "reason" => event.reason,
      "source" => event.source,
      "thread_key" => event.thread_key,
      "delivery_id" => event.delivery_id,
      "metadata" => event.metadata || %{}
    }

    Sessions.append_events(session_id, [
      %{
        ts: event.resolved_at || DateTime.utc_now(),
        type: "inbound.ownership.changed",
        source: event.source || "inbound",
        idempotency_key: "inbound-ownership:#{event.id}",
        payload: payload
      }
    ])
  end

  defp thread_key(session, route) do
    Map.get(route, :thread_key) ||
      Map.get(route, "thread_key") ||
      session.external_id ||
      session.id
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
