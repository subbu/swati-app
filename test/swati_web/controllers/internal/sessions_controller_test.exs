defmodule SwatiWeb.Internal.SessionsControllerTest do
  use SwatiWeb.ConnCase

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions
  alias Swati.Sessions.Session

  setup %{conn: conn} do
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

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        metadata: %{from_address: "+15555550100", to_address: "+15555550200"}
      })

    token = Application.get_env(:swati, :internal_api_token)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, session: session}
  end

  test "end_session accepts closed status", %{conn: conn, session: session} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      status: "closed"
    }

    conn = post(conn, ~p"/internal/v1/sessions/#{session.id}/end", params)
    session_id = session.id
    assert %{"session_id" => ^session_id} = json_response(conn, 200)

    updated = Repo.get!(Session, session.id)
    assert updated.status == :closed
  end

  test "end_session accepts waiting status", %{conn: conn, session: session} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      status: "waiting_on_customer"
    }

    conn = post(conn, ~p"/internal/v1/sessions/#{session.id}/end", params)
    session_id = session.id
    assert %{"session_id" => ^session_id} = json_response(conn, 200)

    updated = Repo.get!(Session, session.id)
    assert updated.status == :waiting_on_customer
  end

  test "end_session renders changeset errors for invalid status", %{conn: conn, session: session} do
    params = %{
      ended_at: "2026-01-01T17:10:02.923690Z",
      status: "bogus"
    }

    conn = post(conn, ~p"/internal/v1/sessions/#{session.id}/end", params)
    assert %{"status" => ["is invalid"]} = json_response(conn, 422)["error"]
  end
end
