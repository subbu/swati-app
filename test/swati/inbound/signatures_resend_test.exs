defmodule Swati.Inbound.SignaturesResendTest do
  use ExUnit.Case, async: true

  alias Swati.Inbound.Signatures.Resend

  test "valid svix signature verifies" do
    raw_body = ~s({"type":"email.received"})
    secret = "whsec_" <> Base.encode64("test-secret")

    svix_id = "msg_123"
    svix_timestamp = Integer.to_string(DateTime.utc_now() |> DateTime.to_unix())

    key = secret |> String.replace_prefix("whsec_", "") |> Base.decode64!()

    signed_content = "#{svix_id}.#{svix_timestamp}.#{raw_body}"

    signature =
      :crypto.mac(:hmac, :sha256, key, signed_content)
      |> Base.encode64()

    headers = %{
      "svix-id" => svix_id,
      "svix-timestamp" => svix_timestamp,
      "svix-signature" => "v1,#{signature}"
    }

    assert :ok = Resend.verify(headers, raw_body, secret)
  end

  test "invalid signature is rejected" do
    headers = %{
      "svix-id" => "msg_123",
      "svix-timestamp" => Integer.to_string(DateTime.utc_now() |> DateTime.to_unix()),
      "svix-signature" => "v1,bad"
    }

    assert {:error, :invalid_signature} =
             Resend.verify(
               headers,
               ~s({"type":"email.received"}),
               "whsec_" <> Base.encode64("abc")
             )
  end
end
