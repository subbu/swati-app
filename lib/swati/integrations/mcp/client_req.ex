defmodule Swati.Integrations.MCP.ClientReq do
  @behaviour Swati.Integrations.MCP.Client

  @impl true
  def request(opts) do
    Req.request(opts)
  end
end
