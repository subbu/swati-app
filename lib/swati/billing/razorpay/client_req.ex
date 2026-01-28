defmodule Swati.Billing.Razorpay.ClientReq do
  @behaviour Swati.Billing.Razorpay.Client

  @impl true
  def request(opts) do
    Req.request(opts)
  end
end
