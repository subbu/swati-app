defmodule Swati.Channels.Outlook.ClientReq do
  @behaviour Swati.Channels.Outlook.Client

  @impl true
  def request(opts) do
    Req.request(opts)
  end
end
