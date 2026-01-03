defmodule Swati.Calls.IngestionTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Calls
  alias Swati.Calls.Ingestion
  alias Swati.Telephony.PhoneNumber

  setup do
    scope = user_scope_fixture()
    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Agent"}, scope.user)

    {:ok, phone_number} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: "+15555550123",
        country: "US",
        status: :active,
        inbound_agent_id: agent.id
      })
      |> Repo.insert()

    {:ok, call} =
      Calls.create_call_start(%{
        tenant_id: scope.tenant.id,
        agent_id: agent.id,
        phone_number_id: phone_number.id,
        provider: :plivo,
        provider_call_id: "call-#{System.unique_integer([:positive])}",
        from_number: "+15555550100",
        to_number: "+15555550200",
        status: :started,
        started_at: DateTime.utc_now()
      })

    {:ok, call: call, scope: scope}
  end

  test "append_events normalizes timestamps and persists", %{call: call, scope: scope} do
    assert :ok =
             Ingestion.append_events(call.id, [
               %{"ts" => "2026-01-01T10:00:00.000000Z", "type" => "plivo_start", "payload" => %{}}
             ])

    call = Calls.get_call!(scope.tenant.id, call.id)
    assert [%{ts: %DateTime{}, type: "plivo_start"}] = call.events
  end
end
