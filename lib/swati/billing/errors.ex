defmodule Swati.Billing.Errors do
  alias Swati.Billing.Error

  def from_provider(body, code, user_message) when is_map(body) do
    provider_message = get_in(body, ["error", "description"]) || inspect(body)
    Error.new(code, user_message, provider_message)
  end

  def from_provider(_body, code, user_message) do
    Error.new(code, user_message)
  end

  def unauthorized do
    Error.new(:unauthorized, "You do not have access to manage billing.")
  end
end
