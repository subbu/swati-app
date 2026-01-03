defmodule Swati.Telephony.PhoneNumberStatusTransitions do
  @allowed %{
    provisioned: [:active, :suspended, :released, :provisioned],
    active: [:active, :suspended, :released],
    suspended: [:active, :suspended, :released],
    released: [:released]
  }

  def allowed?(from_status, to_status) do
    to_status in Map.get(@allowed, from_status, [])
  end

  def ensure_allowed(from_status, to_status) do
    if allowed?(from_status, to_status) do
      :ok
    else
      {:error, :invalid_transition}
    end
  end
end
