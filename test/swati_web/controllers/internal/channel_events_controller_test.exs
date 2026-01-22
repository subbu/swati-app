defmodule SwatiWeb.Internal.ChannelEventsControllerTest do
  use SwatiWeb.ConnCase

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Agents
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

    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Front Desk"}, scope.user)
    {:ok, agent, _version} = Agents.publish_agent(agent, scope.user)
    {:ok, endpoint} = Channels.update_endpoint_routing(endpoint, %{default_agent_id: agent.id})
    {:ok, _agent_channel} = Agents.upsert_agent_channel(agent.id, channel.id, true)

    token = Application.get_env(:swati, :internal_api_token)

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")
      |> put_req_header("authorization", "Bearer #{token}")

    {:ok, conn: conn, scope: scope, endpoint: endpoint}
  end

  test "channel-events ingests inbound event", %{conn: conn, endpoint: endpoint} do
    params = %{
      channel_key: "voice",
      endpoint_address: endpoint.address,
      from_address: "+15555550222",
      session_external_id: "thread-123",
      direction: "inbound",
      event: %{type: "channel.message.received", payload: %{text: "hi"}}
    }

    conn = post(conn, ~p"/internal/v1/channel-events", params)

    assert %{"session_id" => session_id} = json_response(conn, 200)
    assert is_binary(session_id)
  end

  test "channel-actions send rejects missing session", %{conn: conn} do
    conn = post(conn, ~p"/internal/v1/channel-actions/send", %{text: "hello"})

    assert %{"session_id" => ["is required"]} = json_response(conn, 422)["error"]
  end
end
