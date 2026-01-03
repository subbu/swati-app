defmodule Swati.Integrations.MCP.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
