defmodule Swati.Telephony.AnswerUrl do
  alias Swati.Telephony.PhoneNumber

  @spec answer_url(binary()) :: String.t()
  def answer_url(phone_number_id) when is_binary(phone_number_id) do
    base_url = Application.get_env(:swati, :media_gateway_base_url) || ""
    base_url = String.trim_trailing(base_url, "/")
    "#{base_url}/v1/telephony/plivo/answer"
  end

  @spec answer_url_for(PhoneNumber.t()) :: String.t()
  def answer_url_for(%PhoneNumber{id: id}) do
    answer_url(id)
  end
end
