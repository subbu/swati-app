defmodule SwatiWeb.Internal.RuntimeRejectionsControllerTest do
  use SwatiWeb.ConnCase

  import Swati.AccountsFixtures

  alias Swati.Calls.CallRejection
  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "+15555550101"
      })
      |> Repo.insert()

    token = Application.get_env(:swati, :internal_api_token)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, scope: scope, endpoint: endpoint}
  end

  test "stores runtime rejection", %{conn: conn, scope: scope, endpoint: endpoint} do
    params = %{
      provider: "plivo",
      provider_call_id: "call-123",
      session_external_id: "call-123",
      endpoint_address: endpoint.address,
      from_address: "+15555550222",
      channel_key: "voice",
      channel_type: "voice",
      direction: "inbound",
      error: %{
        code: "agent_channel_disabled",
        message: "Agent not enabled for channel.",
        action: "enable_agent_channel",
        retryable: false
      }
    }

    conn = post(conn, ~p"/internal/v1/runtime/rejections", params)

    %{"id" => id} = json_response(conn, 201)
    rejection = Repo.get!(CallRejection, id)

    assert rejection.tenant_id == scope.tenant.id
    assert rejection.reason_code == "agent_channel_disabled"
    assert rejection.provider == "plivo"
    assert rejection.endpoint_id == endpoint.id
  end
end
