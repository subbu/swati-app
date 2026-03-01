defmodule SwatiWeb.InboundWebhookControllerTest do
  use SwatiWeb.ConnCase, async: false

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Inbound
  alias Swati.Sessions

  setup %{conn: conn} do
    scope = user_scope_fixture()

    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Email Agent"}, scope.user)
    {:ok, agent, _version} = Agents.publish_agent(agent, scope.user)

    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)

    {:ok, endpoint} =
      Channels.ensure_endpoint_for_email(scope.tenant.id, "support@example.com", %{
        routing_policy: %{"default_agent_id" => agent.id}
      })

    {:ok, _agent_channel} = Agents.upsert_agent_channel(agent.id, channel.id, true)

    signing_secret = "whsec_" <> Base.encode64("test-signing-secret")

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Resend Inbound",
        signing_secret: signing_secret,
        default_endpoint_address: endpoint.address,
        default_agent_id: agent.id
      })

    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("content-type", "application/json")

    {:ok,
     conn: conn,
     scope: scope,
     agent: agent,
     endpoint: endpoint,
     connector: connector,
     signing_secret: signing_secret}
  end

  test "ingests resend webhook and creates routed email session", %{
    conn: conn,
    scope: scope,
    endpoint: endpoint,
    agent: agent,
    connector: connector,
    signing_secret: signing_secret
  } do
    payload = resend_payload("email_123", endpoint.address)
    raw_body = Jason.encode!(payload)

    {svix_id, svix_timestamp, svix_signature} = sign(raw_body, signing_secret)

    conn =
      conn
      |> put_req_header("svix-id", svix_id)
      |> put_req_header("svix-timestamp", svix_timestamp)
      |> put_req_header("svix-signature", svix_signature)
      |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)

    assert response(conn, 200) == "ok"

    [delivery | _] = Inbound.list_deliveries(scope.tenant.id)
    assert delivery.status == :processed
    assert delivery.signature_valid == true

    session = Sessions.get_session_by_external_id(scope.tenant.id, endpoint.id, "email_123")
    assert session
    assert session.agent_id == agent.id
    assert session.direction == :inbound
  end

  test "duplicate provider event is idempotent", %{
    conn: conn,
    scope: scope,
    endpoint: endpoint,
    connector: connector,
    signing_secret: signing_secret
  } do
    payload = resend_payload("email_dup_123", endpoint.address)
    raw_body = Jason.encode!(payload)

    {svix_id, svix_timestamp, svix_signature} = sign(raw_body, signing_secret)

    conn
    |> put_req_header("svix-id", svix_id)
    |> put_req_header("svix-timestamp", svix_timestamp)
    |> put_req_header("svix-signature", svix_signature)
    |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)
    |> response(200)

    {svix_id_2, svix_timestamp_2, svix_signature_2} = sign(raw_body, signing_secret)

    conn
    |> put_req_header("svix-id", svix_id_2)
    |> put_req_header("svix-timestamp", svix_timestamp_2)
    |> put_req_header("svix-signature", svix_signature_2)
    |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)
    |> response(200)

    deliveries = Inbound.list_deliveries(scope.tenant.id)
    assert length(deliveries) == 1
  end

  test "missing email body falls back to subject text for transcript", %{
    conn: conn,
    scope: scope,
    endpoint: endpoint,
    connector: connector,
    signing_secret: signing_secret
  } do
    payload = %{
      "type" => "email.received",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => %{
        "email_id" => "email_subject_only_123",
        "from" => "customer@example.net",
        "to" => [endpoint.address],
        "subject" => "Need onboarding help"
      }
    }

    raw_body = Jason.encode!(payload)
    {svix_id, svix_timestamp, svix_signature} = sign(raw_body, signing_secret)

    conn
    |> put_req_header("svix-id", svix_id)
    |> put_req_header("svix-timestamp", svix_timestamp)
    |> put_req_header("svix-signature", svix_signature)
    |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)
    |> response(200)

    session =
      Sessions.get_session_by_external_id(scope.tenant.id, endpoint.id, "email_subject_only_123")

    assert session

    [event | _] = Sessions.list_session_events(session.id)
    assert event.type == "channel.message.received"
    assert get_in(event.payload || %{}, ["subject"]) == "Need onboarding help"
    assert get_in(event.payload || %{}, ["text"]) == "Subject: Need onboarding help"
  end

  test "invalid signature is rejected and logged", %{
    conn: conn,
    scope: scope,
    endpoint: endpoint,
    connector: connector
  } do
    payload = resend_payload("email_bad_sig", endpoint.address)
    raw_body = Jason.encode!(payload)

    conn =
      conn
      |> put_req_header("svix-id", "msg_bad")
      |> put_req_header(
        "svix-timestamp",
        Integer.to_string(DateTime.utc_now() |> DateTime.to_unix())
      )
      |> put_req_header("svix-signature", "v1,bad")
      |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)

    assert response(conn, 401) == "invalid signature"

    [delivery | _] = Inbound.list_deliveries(scope.tenant.id)
    assert delivery.status == :failed
    assert delivery.signature_valid == false
  end

  test "failed or processed deliveries can be replayed", %{
    conn: conn,
    scope: scope,
    endpoint: endpoint,
    connector: connector,
    signing_secret: signing_secret
  } do
    payload = resend_payload("email_replay_123", endpoint.address)
    raw_body = Jason.encode!(payload)
    {svix_id, svix_timestamp, svix_signature} = sign(raw_body, signing_secret)

    conn
    |> put_req_header("svix-id", svix_id)
    |> put_req_header("svix-timestamp", svix_timestamp)
    |> put_req_header("svix-signature", svix_signature)
    |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)
    |> response(200)

    [delivery | _] = Inbound.list_deliveries(scope.tenant.id)
    assert delivery.status == :processed

    assert {:ok, replayed} = Inbound.replay_delivery(delivery)
    assert replayed.id == delivery.id
  end

  test "returns 404 when inbound feature flag is disabled", %{
    conn: conn,
    endpoint: endpoint,
    connector: connector,
    signing_secret: signing_secret
  } do
    previous = Application.get_env(:swati, :inbound_connectors_v1)
    Application.put_env(:swati, :inbound_connectors_v1, false)
    on_exit(fn -> Application.put_env(:swati, :inbound_connectors_v1, previous) end)

    payload = resend_payload("email_feature_flag_123", endpoint.address)
    raw_body = Jason.encode!(payload)
    {svix_id, svix_timestamp, svix_signature} = sign(raw_body, signing_secret)

    conn =
      conn
      |> put_req_header("svix-id", svix_id)
      |> put_req_header("svix-timestamp", svix_timestamp)
      |> put_req_header("svix-signature", svix_signature)
      |> post("/api/v1/inbound/#{connector.endpoint_token}", raw_body)

    assert response(conn, 404) == "not found"
  end

  defp resend_payload(email_id, to_address) do
    %{
      "type" => "email.received",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => %{
        "email_id" => email_id,
        "from" => "customer@example.net",
        "to" => [to_address],
        "subject" => "Need help",
        "text" => "Can you help me with my booking?"
      }
    }
  end

  defp sign(raw_body, signing_secret) do
    svix_id = "msg_" <> Integer.to_string(System.unique_integer([:positive]))
    svix_timestamp = Integer.to_string(DateTime.utc_now() |> DateTime.to_unix())

    key =
      signing_secret
      |> String.replace_prefix("whsec_", "")
      |> Base.decode64!()

    signed_content = "#{svix_id}.#{svix_timestamp}.#{raw_body}"

    signature =
      :crypto.mac(:hmac, :sha256, key, signed_content)
      |> Base.encode64()

    {svix_id, svix_timestamp, "v1,#{signature}"}
  end
end
