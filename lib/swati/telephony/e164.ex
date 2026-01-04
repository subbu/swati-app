defmodule Swati.Telephony.E164 do
  @spec normalize(binary()) :: %{normalized: binary(), digits: binary()}
  def normalize(e164) when is_binary(e164) do
    trimmed = String.trim(e164)

    rest = String.trim_leading(trimmed, "+")
    digits = String.replace(rest, ~r/\D/, "")
    normalized = if digits == "", do: digits, else: "+" <> digits

    %{normalized: normalized, digits: digits}
  end
end
