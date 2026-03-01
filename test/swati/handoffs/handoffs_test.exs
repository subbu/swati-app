defmodule Swati.HandoffsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Agents
  alias Swati.Customers
  alias Swati.Handoffs
  alias Swati.Inbound
  alias Swati.Repo
  alias Swati.Sessions

  test "request_handoff and resolve_handoff emit session events" do
    scope = user_scope_fixture()
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, customer} = Customers.create_customer(scope.tenant.id, %{name: "Acme"})

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        customer_id: customer.id
      })

    {:ok, handoff} =
      Handoffs.request_handoff(scope.tenant.id, %{
        session_id: session.id,
        requested_by_type: "agent",
        requested_by_id: "agent-1",
        metadata: %{"reason" => "escalate"}
      })

    {:ok, _handoff} = Handoffs.resolve_handoff(handoff, "accepted")

    events = Sessions.list_session_events(session.id)
    types = Enum.map(events, & &1.type)

    assert "handoff.requested" in types
    assert "handoff.resolved" in types
  end

  test "accepted handoff with target_agent_id transfers ownership and records inbound ownership event" do
    scope = user_scope_fixture()
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, customer} = Customers.create_customer(scope.tenant.id, %{name: "Acme"})
    {:ok, owner_a} = Agents.create_agent(scope.tenant.id, %{name: "Owner A"}, scope.user)
    {:ok, owner_b} = Agents.create_agent(scope.tenant.id, %{name: "Owner B"}, scope.user)

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        customer_id: customer.id,
        external_id: "handoff-thread-1",
        direction: :inbound,
        agent_id: owner_a.id
      })

    {:ok, handoff} =
      Handoffs.request_handoff(scope.tenant.id, %{
        session_id: session.id,
        requested_by_type: "agent",
        requested_by_id: owner_a.id,
        metadata: %{"reason" => "escalate", "target_agent_id" => owner_b.id}
      })

    assert {:ok, _} = Handoffs.resolve_handoff(handoff, "accepted")

    updated_session = Sessions.get_session!(scope.tenant.id, session.id)
    assert updated_session.agent_id == owner_b.id

    ownership_events =
      Inbound.list_thread_ownership_events_for_session(scope.tenant.id, session.id)

    [ownership_event | _] = ownership_events

    assert ownership_event.owner_agent_id == owner_b.id
    assert ownership_event.previous_agent_id == owner_a.id
    assert ownership_event.source == "handoff"
  end
end
