defmodule Swati.Inbound.Signatures.Resend do
  @tolerance_seconds 300

  def verify(headers, raw_body, signing_secret)
      when is_binary(raw_body) and is_binary(signing_secret) do
    svix_id = header(headers, "svix-id")
    svix_timestamp = header(headers, "svix-timestamp")
    svix_signature = header(headers, "svix-signature")

    with true <- (is_binary(svix_id) and svix_id != "") or {:error, :missing_svix_id},
         true <-
           (is_binary(svix_timestamp) and svix_timestamp != "") or
             {:error, :missing_svix_timestamp},
         true <-
           (is_binary(svix_signature) and svix_signature != "") or
             {:error, :missing_svix_signature},
         :ok <- verify_timestamp(svix_timestamp),
         {:ok, key} <- decode_secret(signing_secret),
         true <-
           signature_matches?(key, svix_id, svix_timestamp, raw_body, svix_signature) or
             {:error, :invalid_signature} do
      :ok
    end
  end

  def verify(_headers, _raw_body, _signing_secret), do: {:error, :missing_signing_secret}

  defp header(headers, key) do
    Map.get(headers, key) || Map.get(headers, String.downcase(key))
  end

  defp verify_timestamp(timestamp) do
    case Integer.parse(to_string(timestamp)) do
      {value, ""} ->
        now = DateTime.utc_now() |> DateTime.to_unix()

        if abs(now - value) <= @tolerance_seconds do
          :ok
        else
          {:error, :stale_signature}
        end

      _ ->
        {:error, :invalid_svix_timestamp}
    end
  end

  defp decode_secret("whsec_" <> encoded), do: decode_secret(encoded)

  defp decode_secret(encoded) when is_binary(encoded) do
    case Base.decode64(encoded) do
      {:ok, value} -> {:ok, value}
      :error -> {:ok, encoded}
    end
  end

  defp signature_matches?(key, svix_id, svix_timestamp, raw_body, signatures) do
    signed_content = "#{svix_id}.#{svix_timestamp}.#{raw_body}"

    expected =
      :crypto.mac(:hmac, :sha256, key, signed_content)
      |> Base.encode64()

    signatures
    |> split_signatures()
    |> Enum.any?(fn
      {"v1", signature} -> secure_compare(expected, signature)
      _ -> false
    end)
  end

  defp split_signatures(value) when is_binary(value) do
    value
    |> String.split([" ", ","], trim: true)
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [version, signature] -> {version, signature}
      _ -> {"", ""}
    end)
  end

  defp secure_compare(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right) do
    Plug.Crypto.secure_compare(left, right)
  end

  defp secure_compare(_left, _right), do: false
end
