defmodule Swati.ApprovalsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Approvals
  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Customers
  alias Swati.Repo
  alias Swati.Sessions

  test "request_approval and resolve_approval emit session events" do
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

    {:ok, approval} =
      Approvals.request_approval(scope.tenant.id, %{
        session_id: session.id,
        requested_by_type: "agent",
        requested_by_id: "agent-1",
        request_payload: %{"action" => "refund"}
      })

    {:ok, _approval} =
      Approvals.resolve_approval(approval, "approved", %{
        decision_payload: %{"notes" => "ok"}
      })

    events = Sessions.list_session_events(session.id)
    types = Enum.map(events, & &1.type)

    assert "approval.requested" in types
    assert "approval.resolved" in types
  end
end
