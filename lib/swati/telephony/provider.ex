defmodule Swati.Telephony.Provider do
  @callback search_available_numbers(map()) :: {:ok, list()} | {:error, term()}
  @callback buy_number(String.t(), map()) :: {:ok, map()} | {:error, term()}
  @callback configure_inbound(map(), String.t()) :: {:ok, map()} | {:error, term()}
  @callback release_number(String.t()) :: {:ok, term()} | {:error, term()}
end
