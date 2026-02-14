defmodule SwatiWeb.WhatsAppWebhookControllerTest do
  use SwatiWeb.ConnCase, async: true

  test "verify returns challenge when token matches", %{conn: conn} do
    Application.put_env(:swati, :whatsapp, %{webhook_verify_token: "token"})

    on_exit(fn ->
      Application.delete_env(:swati, :whatsapp)
    end)

    conn =
      get(conn, ~p"/api/v1/webhooks/whatsapp", %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => "token",
        "hub.challenge" => "challenge"
      })

    assert response(conn, 200) == "challenge"
  end

  test "webhook accepts payload", %{conn: conn} do
    Application.put_env(:swati, :whatsapp, %{webhook_verify_token: "token"})

    on_exit(fn ->
      Application.delete_env(:swati, :whatsapp)
    end)

    payload = %{"object" => "whatsapp_business_account", "entry" => []}

    conn = post(conn, ~p"/api/v1/webhooks/whatsapp", payload)

    assert response(conn, 200) == "OK"
  end
end
