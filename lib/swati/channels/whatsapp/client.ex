defmodule Swati.Channels.WhatsApp.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
