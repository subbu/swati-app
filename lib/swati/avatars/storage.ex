defmodule Swati.Avatars.Storage do
  def store_from_url(agent_id, source_url) when is_binary(source_url) do
    response =
      Req.get!(source_url,
        decode_body: false,
        receive_timeout: 30_000
      )

    content_type = content_type(response.headers) || "image/png"
    extension = extension_from_content_type(content_type)
    key = object_key(agent_id, extension)

    with :ok <- upload_to_s3(key, response.body, content_type) do
      {:ok, %{key: key, public_url: public_url_for_key(key)}}
    end
  rescue
    exception -> {:error, exception}
  end

  defp upload_to_s3(key, body, content_type) do
    config = s3_config!()
    url = upload_url(config, key)
    headers = signed_headers(config, url, body, content_type)

    response =
      Req.put!(url,
        body: body,
        headers: headers,
        receive_timeout: 30_000
      )

    if response.status in 200..299 do
      :ok
    else
      {:error, "S3 upload failed with status #{response.status}"}
    end
  end

  @doc false
  def object_key(_agent_id, extension) do
    "avatar-#{Ecto.UUID.generate()}.#{extension}"
  end

  defp upload_url(%{bucket: bucket, region: region, endpoint: nil}, key) do
    "https://#{bucket}.s3.#{region}.amazonaws.com/#{key}"
  end

  defp upload_url(%{bucket: bucket, endpoint: endpoint}, key) do
    endpoint = endpoint |> normalize_endpoint() |> String.trim_trailing("/")
    "#{endpoint}/#{bucket}/#{key}"
  end

  @doc false
  def public_url_for_key(key) do
    case Application.get_env(:swati, :avatar_s3_public_base_url) do
      nil -> upload_url(s3_config!(), key)
      base -> (base |> normalize_endpoint() |> String.trim_trailing("/")) <> "/" <> key
    end
  end

  defp signed_headers(config, url, body, content_type) do
    uri = URI.parse(url)
    host = host_header(uri)
    now = DateTime.utc_now()
    amz_date = Calendar.strftime(now, "%Y%m%dT%H%M%SZ")
    date_stamp = Calendar.strftime(now, "%Y%m%d")
    payload_hash = hash_sha256(body)

    canonical_uri = encode_path(uri.path || "/")
    canonical_query = ""

    headers = [
      {"content-type", content_type},
      {"host", host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date}
    ]

    {canonical_headers, signed_headers} = canonicalize_headers(headers)

    canonical_request =
      Enum.join(
        [
          "PUT",
          canonical_uri,
          canonical_query,
          canonical_headers,
          signed_headers,
          payload_hash
        ],
        "\n"
      )

    credential_scope = "#{date_stamp}/#{config.region}/s3/aws4_request"

    string_to_sign =
      Enum.join(
        [
          "AWS4-HMAC-SHA256",
          amz_date,
          credential_scope,
          hash_sha256(canonical_request)
        ],
        "\n"
      )

    signature = sign(string_to_sign, config.secret_access_key, date_stamp, config.region)

    authorization =
      "AWS4-HMAC-SHA256 Credential=#{config.access_key_id}/#{credential_scope}, SignedHeaders=#{signed_headers}, Signature=#{signature}"

    [
      {"content-type", content_type},
      {"host", host},
      {"x-amz-content-sha256", payload_hash},
      {"x-amz-date", amz_date},
      {"authorization", authorization}
    ]
  end

  defp host_header(%URI{host: host, port: nil}), do: host
  defp host_header(%URI{host: host, port: 80}), do: host
  defp host_header(%URI{host: host, port: 443}), do: host
  defp host_header(%URI{host: host, port: port}), do: "#{host}:#{port}"

  defp canonicalize_headers(headers) do
    headers =
      headers
      |> Enum.map(fn {key, value} ->
        {String.downcase(key), value |> normalize_header_value() |> String.trim()}
      end)
      |> Enum.sort_by(fn {key, _} -> key end)

    canonical_headers =
      headers
      |> Enum.map(fn {key, value} -> "#{key}:#{value}\n" end)
      |> Enum.join()

    signed_headers =
      headers
      |> Enum.map(fn {key, _} -> key end)
      |> Enum.join(";")

    {canonical_headers, signed_headers}
  end

  defp normalize_header_value(nil), do: ""
  defp normalize_header_value(value) when is_binary(value), do: value
  defp normalize_header_value(value), do: to_string(value)

  defp hash_sha256(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end

  defp sign(string_to_sign, secret_access_key, date_stamp, region) do
    k_date = hmac("AWS4" <> secret_access_key, date_stamp)
    k_region = hmac(k_date, region)
    k_service = hmac(k_region, "s3")
    k_signing = hmac(k_service, "aws4_request")
    hmac(k_signing, string_to_sign) |> Base.encode16(case: :lower)
  end

  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)

  defp encode_path(path) do
    path
    |> String.split("/", trim: false)
    |> Enum.map(fn
      "" -> ""
      segment -> URI.encode(segment, &URI.char_unreserved?/1)
    end)
    |> Enum.join("/")
  end

  defp s3_config! do
    %{
      bucket: fetch_config!(:avatar_s3_bucket),
      region: fetch_config!(:avatar_s3_region),
      access_key_id: fetch_config!(:avatar_s3_access_key_id),
      secret_access_key: fetch_config!(:avatar_s3_secret_access_key),
      endpoint: Application.get_env(:swati, :avatar_s3_endpoint)
    }
  end

  defp fetch_config!(key) do
    Application.get_env(:swati, key) ||
      raise "Missing #{key} configuration for S3 avatar storage."
  end

  defp extension_from_content_type(content_type) do
    cond do
      is_binary(content_type) and String.contains?(content_type, "png") -> "png"
      is_binary(content_type) and String.contains?(content_type, "jpeg") -> "jpg"
      is_binary(content_type) and String.contains?(content_type, "jpg") -> "jpg"
      true -> "png"
    end
  end

  defp content_type(headers) do
    headers
    |> Enum.find_value(fn {key, value} ->
      if String.downcase(key) == "content-type", do: value
    end)
  end

  defp normalize_endpoint(nil), do: nil

  defp normalize_endpoint(endpoint) when is_binary(endpoint) do
    endpoint = String.trim(endpoint)

    if String.starts_with?(endpoint, ["http://", "https://"]) do
      endpoint
    else
      "https://#{endpoint}"
    end
  end
end
