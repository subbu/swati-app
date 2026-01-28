defmodule Swati.Billing.Invoices do
  require Logger

  alias Swati.Billing.Razorpay

  def list_for_subscription(subscription_id, count \\ 10)
      when is_binary(subscription_id) and is_integer(count) do
    case Razorpay.fetch_invoices(subscription_id, count) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, Map.get(body, "items", [])}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.warning("razorpay invoices failed status=#{status} body=#{inspect(body)}")
        {:error, :provider_error}

      {:error, reason} ->
        Logger.warning("razorpay invoices error=#{inspect(reason)}")
        {:error, reason}
    end
  end
end
