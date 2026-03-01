defmodule Swati.Inbound.ResendClient do
  @api_base "https://api.resend.com"

  def fetch_email(nil), do: {:ok, nil}

  def fetch_email(email_id) when is_binary(email_id) do
    with {:ok, api_key} <- api_key(),
         {:ok, response} <- request_email(email_id, api_key) do
      {:ok, parse_body(response.body)}
    end
  end

  defp request_email(email_id, api_key) do
    Req.request(
      method: :get,
      url: "#{@api_base}/emails/#{email_id}",
      headers: [authorization: "Bearer #{api_key}"],
      receive_timeout: 15_000
    )
  end

  defp parse_body(%{"data" => data}) when is_map(data), do: data
  defp parse_body(body) when is_map(body), do: body
  defp parse_body(_), do: %{}

  defp api_key do
    mailer_config = Application.get_env(:swati, Swati.Mailer, [])
    api_key = Keyword.get(mailer_config, :api_key)

    if is_binary(api_key) and String.trim(api_key) != "" do
      {:ok, api_key}
    else
      {:error, :missing_resend_api_key}
    end
  end
end
