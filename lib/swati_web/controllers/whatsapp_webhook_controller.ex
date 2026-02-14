defmodule SwatiWeb.WhatsAppWebhookController do
  use SwatiWeb, :controller

  alias Swati.Channels.WhatsApp

  def verify(conn, params) do
    verify_token = WhatsApp.config().webhook_verify_token

    case params do
      %{
        "hub.mode" => "subscribe",
        "hub.verify_token" => ^verify_token,
        "hub.challenge" => challenge
      } ->
        send_resp(conn, 200, challenge)

      _ ->
        send_resp(conn, 403, "Forbidden")
    end
  end

  def webhook(conn, params) do
    _ = Task.start(fn -> WhatsApp.handle_webhook(params) end)
    send_resp(conn, 200, "OK")
  end
end
