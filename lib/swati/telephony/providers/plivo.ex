defmodule Swati.Telephony.Providers.Plivo do
  @behaviour Swati.Telephony.Provider

  # Verify against Plivo docs before using in production.

  def search_available_numbers(params) do
    request(:get, endpoint("PhoneNumber/"), params)
  end

  def buy_number(e164, opts) do
    request(:post, endpoint("PhoneNumber/#{e164}/"), opts)
  end

  def configure_inbound(number_meta, answer_url) do
    request(:post, endpoint("Application/"), Map.put(number_meta, "answer_url", answer_url))
  end

  def release_number(provider_number_id) do
    request(:delete, endpoint("PhoneNumber/#{provider_number_id}/"), %{})
  end

  defp request(method, url, params) do
    with {:ok, auth} <- credentials() do
      req =
        Req.new(
          method: method,
          url: url,
          auth: {:basic, auth},
          headers: [{"accept", "application/json"}]
        )

      result =
        case method do
          :get -> Req.request(req, params: params)
          :delete -> Req.request(req)
          _ -> Req.request(req, json: params)
        end

      case result do
        {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
        {:ok, %{status: status, body: body}} -> {:error, {status, body}}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp credentials do
    auth_id = System.get_env("PLIVO_AUTH_ID")
    auth_token = System.get_env("PLIVO_AUTH_TOKEN")

    if is_binary(auth_id) and is_binary(auth_token) do
      {:ok, {auth_id, auth_token}}
    else
      {:error, :missing_credentials}
    end
  end

  defp endpoint(path) do
    base = System.get_env("PLIVO_BASE_URL", "https://api.plivo.com/v1/Account")
    auth_id = System.get_env("PLIVO_AUTH_ID", "")

    [base, auth_id, path]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end
end
