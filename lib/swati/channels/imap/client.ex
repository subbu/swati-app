defmodule Swati.Channels.Imap.Client do
  @callback start_connection_ssl(String.t(), integer()) ::
              {:ok, {term(), term()}} | {:error, term()}
  @callback start_connection(String.t(), integer()) :: {:ok, {term(), term()}} | {:error, term()}
  @callback login(term(), String.t(), String.t()) :: term()
  @callback select(term(), String.t()) :: term()
  @callback uid_search(term(), String.t()) :: term()
  @callback uid_fetch(term(), integer(), integer(), String.t(), integer()) :: term()
  @callback logout(term()) :: term()
end
