defmodule Swati.Billing.Razorpay.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
