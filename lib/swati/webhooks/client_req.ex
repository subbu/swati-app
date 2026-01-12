defmodule Swati.Webhooks.ClientReq do
  @behaviour Swati.Webhooks.Client

  @impl true
  def request(opts) do
    Req.request(opts)
  end
end
