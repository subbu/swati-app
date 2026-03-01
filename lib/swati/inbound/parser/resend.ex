defmodule Swati.Inbound.Parser.Resend do
  @moduledoc false

  def normalize(payload, fetched_email \\ nil) when is_map(payload) do
    data = Map.get(payload, "data") || payload

    from =
      fetched_field(fetched_email, ["from", "from_address"]) ||
        Map.get(data, "from") ||
        Map.get(data, "from_address")

    to_addresses =
      fetched_list(fetched_email, ["to"]) ||
        normalize_addresses(Map.get(data, "to"))

    cc_addresses =
      fetched_list(fetched_email, ["cc"]) ||
        normalize_addresses(Map.get(data, "cc"))

    bcc_addresses =
      fetched_list(fetched_email, ["bcc"]) ||
        normalize_addresses(Map.get(data, "bcc"))

    subject =
      fetched_field(fetched_email, ["subject"]) ||
        Map.get(data, "subject") ||
        Map.get(payload, "subject")

    text_body =
      fetched_field(fetched_email, ["text", "text_body", "body"]) ||
        Map.get(data, "text") ||
        Map.get(data, "text_body") ||
        Map.get(data, "body")

    html_body =
      fetched_field(fetched_email, ["html", "html_body"]) ||
        Map.get(data, "html") ||
        Map.get(data, "html_body")

    attachments =
      fetched_list(fetched_email, ["attachments"]) ||
        normalize_list(Map.get(data, "attachments"))

    message_id =
      fetched_field(fetched_email, ["message_id", "id"]) ||
        Map.get(data, "message_id") ||
        Map.get(data, "email_id") ||
        Map.get(payload, "id")

    in_reply_to =
      fetched_field(fetched_email, ["in_reply_to"]) ||
        Map.get(data, "in_reply_to")

    references =
      fetched_list(fetched_email, ["references"]) ||
        normalize_list(Map.get(data, "references"))

    provider_thread_id =
      fetched_field(fetched_email, ["thread_id", "provider_thread_id"]) ||
        Map.get(data, "thread_id") ||
        Map.get(data, "provider_thread_id")

    event_type = Map.get(payload, "type") || Map.get(payload, "event") || "email.received"

    provider_event_id =
      Map.get(payload, "id") ||
        Map.get(data, "email_id") ||
        message_id ||
        fallback_event_id(payload)

    received_at =
      parse_datetime(Map.get(payload, "created_at")) ||
        parse_datetime(Map.get(data, "created_at")) ||
        DateTime.utc_now()

    %{
      "provider" => "resend",
      "event_type" => event_type,
      "provider_event_id" => provider_event_id,
      "received_at" => DateTime.to_iso8601(received_at),
      "from" => to_string_or_nil(from),
      "to" => to_addresses,
      "cc" => cc_addresses,
      "bcc" => bcc_addresses,
      "subject" => to_string_or_nil(subject),
      "text_body" => to_string_or_nil(text_body),
      "html_body" => to_string_or_nil(html_body),
      "attachments" => attachments,
      "message_id" => to_string_or_nil(message_id),
      "in_reply_to" => to_string_or_nil(in_reply_to),
      "references" => references,
      "provider_thread_id" => to_string_or_nil(provider_thread_id),
      "headers" => normalize_headers(Map.get(data, "headers")),
      "raw_payload" => payload
    }
  end

  defp fetched_field(nil, _keys), do: nil

  defp fetched_field(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp fetched_list(nil, _keys), do: nil

  defp fetched_list(map, keys) do
    keys
    |> Enum.find_value(fn key ->
      value = Map.get(map, key)
      if is_nil(value), do: nil, else: normalize_addresses(value)
    end)
  end

  defp normalize_addresses(nil), do: []

  defp normalize_addresses(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_addresses(value) when is_list(value) do
    value
    |> Enum.flat_map(fn
      item when is_binary(item) -> [String.trim(item)]
      %{"email" => email} when is_binary(email) -> [String.trim(email)]
      %{email: email} when is_binary(email) -> [String.trim(email)]
      _ -> []
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_addresses(_value), do: []

  defp normalize_list(nil), do: []
  defp normalize_list(value) when is_list(value), do: value
  defp normalize_list(value), do: [value]

  defp normalize_headers(headers) when is_map(headers), do: headers
  defp normalize_headers(_headers), do: %{}

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(_value), do: nil

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value) when is_binary(value), do: value
  defp to_string_or_nil(value), do: to_string(value)

  defp fallback_event_id(payload) do
    payload
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
