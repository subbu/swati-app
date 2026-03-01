defmodule SwatiWeb.InboundWebhookController do
  use SwatiWeb, :controller

  require Logger

  alias Swati.Inbound

  def webhook(conn, %{"connector_token" => connector_token}) do
    headers = headers_map(conn.req_headers)
    raw_body = conn.assigns[:raw_body] || ""

    case Inbound.ingest_webhook(connector_token, headers, raw_body, conn.body_params) do
      {:ok, _result} ->
        send_resp(conn, 200, "ok")

      {:error, :connector_not_found} ->
        send_resp(conn, 404, "not found")

      {:error, :connector_disabled} ->
        send_resp(conn, 403, "connector disabled")

      {:error, :feature_disabled} ->
        send_resp(conn, 404, "not found")

      {:error, reason}
      when reason in [
             :missing_svix_id,
             :missing_svix_timestamp,
             :missing_svix_signature,
             :invalid_signature,
             :stale_signature,
             :invalid_svix_timestamp,
             :missing_signing_secret
           ] ->
        send_resp(conn, 401, "invalid signature")

      {:error, reason} ->
        Logger.warning("inbound webhook failed reason=#{inspect(reason)}")
        send_resp(conn, 400, "bad request")
    end
  end

  defp headers_map(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, acc ->
      Map.put(acc, String.downcase(key), value)
    end)
  end
end
