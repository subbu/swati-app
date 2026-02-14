defmodule Swati.Channels.WhatsApp.MetaClient do
  @graph_url "https://graph.facebook.com"

  def exchange_code_for_token(code, config) do
    params = %{
      "client_id" => config.app_id,
      "client_secret" => config.app_secret,
      "code" => code
    }

    request_json(:get, oauth_url(config), params: params)
  end

  def debug_token(access_token, config) do
    params = %{
      "input_token" => access_token,
      "access_token" => app_access_token(config)
    }

    request_json(:get, debug_url(config), params: params)
  end

  def list_phone_numbers(waba_id, access_token, config) do
    request_json(:get, phone_numbers_url(config, waba_id), headers: auth_headers(access_token))
  end

  def subscribe_app(waba_id, access_token, config) do
    request_json(:post, subscribed_apps_url(config, waba_id), headers: auth_headers(access_token))
  end

  def refresh_token(access_token, config) do
    params = %{
      "grant_type" => "fb_exchange_token",
      "client_id" => config.app_id,
      "client_secret" => config.app_secret,
      "fb_exchange_token" => access_token
    }

    request_json(:get, oauth_url(config), params: params)
  end

  def send_message(phone_number_id, access_token, payload, config) do
    request_json(:post, messages_url(config, phone_number_id),
      headers: auth_headers(access_token),
      json: payload
    )
  end

  defp request_json(method, url, opts) do
    opts = Keyword.merge([method: method, url: url, http_errors: :return], opts)

    case client().request(opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp auth_headers(access_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"accept", "application/json"}
    ]
  end

  defp app_access_token(config), do: "#{config.app_id}|#{config.app_secret}"

  defp oauth_url(config), do: "#{@graph_url}/#{config.graph_api_version}/oauth/access_token"
  defp debug_url(config), do: "#{@graph_url}/#{config.graph_api_version}/debug_token"

  defp phone_numbers_url(config, waba_id),
    do: "#{@graph_url}/#{config.graph_api_version}/#{waba_id}/phone_numbers"

  defp subscribed_apps_url(config, waba_id),
    do: "#{@graph_url}/#{config.graph_api_version}/#{waba_id}/subscribed_apps"

  defp messages_url(config, phone_number_id),
    do: "#{@graph_url}/#{config.graph_api_version}/#{phone_number_id}/messages"

  defp client do
    Application.get_env(:swati, :whatsapp_client, Swati.Channels.WhatsApp.ClientReq)
  end
end
