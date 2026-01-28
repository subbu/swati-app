defmodule SwatiWeb.BillingWebhookController do
  use SwatiWeb, :controller

  require Logger

  alias Swati.Billing
  alias Swati.Billing.Razorpay

  def razorpay(conn, _params) do
    signature = conn |> get_req_header("x-razorpay-signature") |> List.first()
    raw_body = conn.assigns[:raw_body] || ""

    with :ok <- Razorpay.verify_signature(raw_body, signature),
         :ok <- Billing.ingest_razorpay_webhook(conn.body_params, raw_body) do
      send_resp(conn, 200, "ok")
    else
      {:error, :missing_signature} ->
        send_resp(conn, 401, "missing signature")

      {:error, :invalid_signature} ->
        send_resp(conn, 401, "invalid signature")

      {:error, reason} ->
        Logger.warning("billing webhook failed reason=#{inspect(reason)}")
        send_resp(conn, 400, "bad request")
    end
  end
end
