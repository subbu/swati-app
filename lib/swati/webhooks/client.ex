defmodule Swati.Webhooks.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
