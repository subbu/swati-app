defmodule SwatiWeb.Internal.CallsControllerTest do
  use SwatiWeb.ConnCase

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Calls
  alias Swati.Calls.Call
  alias Swati.Repo

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Test Agent"}, scope.user)

    {:ok, call} =
      Calls.create_call_start(%{
        tenant_id: scope.tenant.id,
        agent_id: agent.id,
        provider: :plivo,
        provider_call_id: "call-#{System.unique_integer([:positive])}",
        from_number: "+15555550100",
        to_number: "+15555550200",
        status: :started,
        started_at: DateTime.utc_now()
      })

    token = Application.get_env(:swati, :internal_api_token)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, call: call}
  end

  test "end_call accepts cancelled status", %{conn: conn, call: call} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      duration_seconds: 33,
      status: "cancelled"
    }

    conn = post(conn, ~p"/internal/v1/calls/#{call.id}/end", params)
    call_id = call.id
    assert %{"call_id" => ^call_id} = json_response(conn, 200)

    updated = Repo.get!(Call, call.id)
    assert updated.status == :cancelled
  end

  test "end_call accepts error status", %{conn: conn, call: call} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      duration_seconds: 33,
      status: "error"
    }

    conn = post(conn, ~p"/internal/v1/calls/#{call.id}/end", params)
    call_id = call.id
    assert %{"call_id" => ^call_id} = json_response(conn, 200)

    updated = Repo.get!(Call, call.id)
    assert updated.status == :error
  end

  test "end_call renders changeset errors for invalid status", %{conn: conn, call: call} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      duration_seconds: 33,
      status: "bogus"
    }

    conn = post(conn, ~p"/internal/v1/calls/#{call.id}/end", params)
    assert %{"status" => ["is invalid"]} = json_response(conn, 422)["error"]
  end
end
