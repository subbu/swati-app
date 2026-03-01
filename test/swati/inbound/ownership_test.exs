defmodule Swati.Inbound.OwnershipTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Customers
  alias Swati.Inbound
  alias Swati.Inbound.Ownership
  alias Swati.Sessions

  test "record_route inserts ownership event once per owner" do
    scope = user_scope_fixture()

    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Owner Agent"}, scope.user)
    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)
    {:ok, _} = Agents.upsert_agent_channel(agent.id, channel.id, true)
    {:ok, endpoint} = Channels.ensure_endpoint_for_email(scope.tenant.id, "support@test.local")

    {:ok, customer} =
      Customers.create_customer(scope.tenant.id, %{name: "Acme", primary_email: "a@b.c"})

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        customer_id: customer.id,
        external_id: "thread-ownership-test",
        direction: :inbound,
        agent_id: agent.id
      })

    route = %{
      owner_agent_id: agent.id,
      route_reason: "continuity",
      thread_key: "thread-ownership-test"
    }

    assert {:ok, _event} = Ownership.record_route(session, route, %{delivery_id: nil})
    assert {:ok, _event} = Ownership.record_route(session, route, %{delivery_id: nil})

    events = Inbound.list_thread_ownership_events_for_session(scope.tenant.id, session.id)
    assert length(events) == 1
    assert hd(events).owner_agent_id == agent.id
    assert hd(events).reason == "continuity"
  end
end
