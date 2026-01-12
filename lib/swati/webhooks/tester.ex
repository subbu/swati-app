defmodule Swati.Webhooks.Tester do
  alias Swati.Repo
  alias Swati.Webhooks.ClientReq
  alias Swati.Webhooks.Secrets
  alias Swati.Webhooks.Webhook

  def test_webhook(%Webhook{} = webhook) do
    case send_request(webhook) do
      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        update_test_status(webhook, {:ok, "success", nil})

      {:ok, %Req.Response{status: status, body: body}} ->
        update_test_status(webhook, {:error, "error", response_error(body, status)})

      {:error, error} ->
        update_test_status(webhook, {:error, "error", Exception.message(error)})
    end
  end

  defp send_request(webhook) do
    payload = webhook.sample_payload || %{}
    method = webhook.http_method || :post
    timeout = (webhook.timeout_secs || 15) * 1_000

    headers = base_headers(webhook, method)

    opts =
      [
        method: method,
        url: webhook.endpoint_url,
        headers: headers,
        receive_timeout: timeout
      ]
      |> put_payload(method, payload)

    client().request(opts)
  end

  defp base_headers(webhook, method) do
    base = [{"accept", "application/json"}]

    body_headers =
      if method in [:post, :put, :patch] do
        [{"content-type", "application/json"}]
      else
        []
      end

    custom =
      (webhook.headers || %{})
      |> Map.new()
      |> Enum.map(fn {key, value} -> {String.downcase(to_string(key)), to_string(value)} end)

    auth = Secrets.auth_headers(webhook)

    base ++ body_headers ++ custom ++ auth
  end

  defp put_payload(opts, method, payload) when method in [:get, :delete] do
    if payload == %{} do
      opts
    else
      Keyword.put(opts, :params, payload)
    end
  end

  defp put_payload(opts, _method, payload) do
    Keyword.put(opts, :json, payload)
  end

  defp update_test_status(webhook, {status, label, error}) do
    changes = %{
      last_tested_at: DateTime.utc_now(),
      last_test_status: label,
      last_test_error: error
    }

    webhook
    |> Ecto.Changeset.change(changes)
    |> Repo.update()
    |> case do
      {:ok, updated} -> {status, updated}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp response_error(%{"error" => %{"message" => message}}, _status), do: message
  defp response_error(body, _status) when is_binary(body), do: body
  defp response_error(_body, status), do: "Unexpected status: #{status}"

  defp client do
    Application.get_env(:swati, :webhook_client, ClientReq)
  end
end
