defmodule Swati.Channels.Gmail.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
