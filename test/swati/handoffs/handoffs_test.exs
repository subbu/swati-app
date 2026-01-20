defmodule Swati.HandoffsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Customers
  alias Swati.Handoffs
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
end
