defmodule Swati.Billing.Error do
  defstruct [:code, :user_message, :provider_message]

  def new(code, user_message, provider_message \\ nil) do
    %__MODULE__{code: code, user_message: user_message, provider_message: provider_message}
  end
end
