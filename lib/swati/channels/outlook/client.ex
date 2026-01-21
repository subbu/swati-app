defmodule Swati.Channels.Outlook.Client do
  @callback request(keyword()) :: {:ok, Req.Response.t()} | {:error, term()}
end
