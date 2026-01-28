defmodule Swati.Telephony.Providers.Plivo do
  @behaviour Swati.Telephony.Provider

  # Verify against Plivo docs before using in production.

  require Logger

  @search_params ~w(country_iso type pattern npanxx local_calling_area region services city region_city lata rate_center limit offset compliance_requirement)
  @buy_params ~w(app_id cnam_lookup)

  def search_available_numbers(params) do
    request(:get, endpoint("PhoneNumber/"), filter_params(params, @search_params))
  end

  def buy_number(e164, opts) do
    request(:post, endpoint("PhoneNumber/#{e164}/"), filter_params(opts, @buy_params))
  end

  def configure_inbound(number_meta, answer_url) do
    provider_number_id =
      Map.get(number_meta, "provider_number_id") || Map.get(number_meta, :provider_number_id)

    with {:ok, app} <-
           request(:post, endpoint("Application/"), %{
             "answer_url" => answer_url,
             "app_name" => app_name(provider_number_id)
           }),
         app_id when is_binary(app_id) <- Map.get(app, "app_id") || Map.get(app, :app_id),
         provider_number_id when is_binary(provider_number_id) <- provider_number_id,
         {:ok, _} <-
           request(:post, endpoint("Number/#{provider_number_id}/"), %{"app_id" => app_id}) do
      {:ok, %{"app_id" => app_id}}
    else
      nil -> {:error, :missing_app_id}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :missing_provider_number_id}
    end
  end

  def release_number(provider_number_id) do
    request(:delete, endpoint("PhoneNumber/#{provider_number_id}/"), %{})
  end

  defp request(method, url, params) do
    with {:ok, {auth_id, auth_token}} <- credentials() do
      redacted_url = redact_url(url)

      Logger.debug("plivo request method=#{method} url=#{redacted_url} params=#{inspect(params)}")

      req =
        Req.new(
          method: method,
          url: url,
          auth: {:basic, "#{auth_id}:#{auth_token}"},
          headers: [{"accept", "application/json"}]
        )

      result =
        case method do
          :get -> Req.request(req, params: params)
          :delete -> Req.request(req)
          _ -> Req.request(req, json: params)
        end

      case result do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          Logger.debug(
            "plivo response status=#{status} url=#{redacted_url} body=#{inspect(summarize_body(body))}"
          )

          {:ok, body}

        {:ok, %{status: status, body: body}} ->
          Logger.warning(
            "plivo response error status=#{status} url=#{redacted_url} body=#{inspect(body)}"
          )

          {:error, {status, body}}

        {:error, error} ->
          Logger.warning("plivo request error url=#{redacted_url} error=#{inspect(error)}")

          {:error, error}
      end
    end
  end

  defp credentials do
    auth_id = Application.get_env(:swati, :plivo_auth_id) || System.get_env("PLIVO_AUTH_ID")

    auth_token =
      Application.get_env(:swati, :plivo_auth_token) || System.get_env("PLIVO_AUTH_TOKEN")

    if is_binary(auth_id) and is_binary(auth_token) do
      {:ok, {auth_id, auth_token}}
    else
      Logger.warning("plivo credentials missing")
      {:error, :missing_credentials}
    end
  end

  defp endpoint(path) do
    base = System.get_env("PLIVO_BASE_URL", "https://api.plivo.com/v1/Account")
    auth_id = Application.get_env(:swati, :plivo_auth_id) || System.get_env("PLIVO_AUTH_ID", "")

    [base, auth_id, path]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("/")
  end

  defp filter_params(params, allowed) when is_map(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      key = to_string(key)

      cond do
        key not in allowed -> acc
        is_nil(value) -> acc
        value == "" -> acc
        true -> Map.put(acc, key, value)
      end
    end)
  end

  defp redact_url(url) when is_binary(url) do
    Regex.replace(~r{/Account/[^/]+/}, url, "/Account/[redacted]/")
  end

  defp redact_url(url), do: inspect(url)

  defp app_name(provider_number_id) when is_binary(provider_number_id) do
    "swati-#{provider_number_id}-#{System.unique_integer([:positive])}"
  end

  defp app_name(_provider_number_id) do
    "swati-#{System.unique_integer([:positive])}"
  end

  defp summarize_body(body) when is_map(body), do: Map.keys(body)
  defp summarize_body(body) when is_list(body), do: "list(#{length(body)})"
  defp summarize_body(body) when is_binary(body), do: "binary(#{byte_size(body)})"
  defp summarize_body(body), do: body
end
