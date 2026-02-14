defmodule Swati.Channels.WhatsApp.ClientReq do
  @behaviour Swati.Channels.WhatsApp.Client

  @impl true
  def request(opts) do
    Req.request(opts)
  end
end
