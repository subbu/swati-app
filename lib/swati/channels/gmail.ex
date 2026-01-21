defmodule Swati.Channels.Gmail do
  alias Swati.Channels
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Ingestion
  alias Swati.Channels.Secrets
  alias Swati.Repo

  @auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v2/userinfo"
  @gmail_api "https://gmail.googleapis.com/gmail/v1"

  @scopes [
    "openid",
    "email",
    "profile",
    "https://www.googleapis.com/auth/gmail.readonly",
    "https://www.googleapis.com/auth/gmail.send"
  ]

  def authorization_url(state, redirect_uri) do
    with {:ok, %{client_id: client_id}} <- oauth_config(),
         true <- is_binary(redirect_uri) do
      params = %{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "access_type" => "offline",
        "prompt" => "consent",
        "include_granted_scopes" => "true",
        "scope" => Enum.join(@scopes, " "),
        "state" => state
      }

      {:ok, @auth_url <> "?" <> URI.encode_query(params)}
    else
      _ -> {:error, :missing_gmail_oauth_config}
    end
  end

  def connect(tenant_id, code, redirect_uri) do
    with {:ok, token} <- exchange_code(code, redirect_uri),
         token <- normalize_token(token),
         {:ok, profile} <- fetch_profile(Map.get(token, "access_token")),
         email when is_binary(email) <- Map.get(profile, "email"),
         {:ok, channel} <- Channels.ensure_email_channel(tenant_id),
         {:ok, endpoint} <-
           Channels.ensure_endpoint(tenant_id, channel.id, email, %{
             "metadata" => %{"provider" => "gmail"}
           }),
         {:ok, connection} <- upsert_connection(tenant_id, channel, endpoint, token, profile) do
      {:ok, connection}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :gmail_profile_missing}
    end
  end

  def sync_connection(%ChannelConnection{} = connection) do
    connection = Repo.preload(connection, [:endpoint, :channel])

    with {:ok, access_token, token} <- ensure_access_token(connection),
         {:ok, messages} <- list_messages(access_token, connection.last_synced_at),
         :ok <- ingest_messages(connection, messages) do
      :ok = update_token_secret(connection, token)

      connection
      |> ChannelConnection.changeset(%{last_synced_at: DateTime.utc_now(), status: :active})
      |> Repo.update()

      {:ok, %{synced: length(messages)}}
    else
      {:error, reason} ->
        _ = update_connection_status(connection, :error, %{"sync_error" => inspect(reason)})
        {:error, reason}
    end
  end

  def send_message(%ChannelConnection{} = connection, attrs) when is_map(attrs) do
    connection = Repo.preload(connection, [:endpoint])

    to = Map.get(attrs, "to") || Map.get(attrs, :to)
    subject = Map.get(attrs, "subject") || Map.get(attrs, :subject) || ""
    text = Map.get(attrs, "text") || Map.get(attrs, :text) || ""
    thread_id = Map.get(attrs, "thread_id") || Map.get(attrs, :thread_id)

    if is_nil(to) or text == "" do
      {:error, :message_payload_invalid}
    else
      with {:ok, access_token, token} <- ensure_access_token(connection),
           {:ok, response} <-
             send_gmail(access_token, connection.endpoint.address, to, subject, text, thread_id) do
        :ok = update_token_secret(connection, token)
        {:ok, response}
      end
    end
  end

  defp exchange_code(code, redirect_uri) do
    with {:ok, %{client_id: client_id, client_secret: client_secret}} <- oauth_config() do
      params = %{
        "code" => code,
        "client_id" => client_id,
        "client_secret" => client_secret,
        "redirect_uri" => redirect_uri,
        "grant_type" => "authorization_code"
      }

      request_json(:post, @token_url, form: params)
    end
  end

  defp fetch_profile(nil), do: {:error, :missing_access_token}

  defp fetch_profile(access_token) do
    request_json(:get, @userinfo_url, headers: auth_headers(access_token))
  end

  defp ensure_access_token(%ChannelConnection{} = connection) do
    token = read_token(connection)

    case token do
      %{"access_token" => access_token, "expires_at" => expires_at} = token_map ->
        if token_expired?(expires_at) do
          refresh_access_token(connection, token_map)
        else
          {:ok, access_token, token_map}
        end

      %{"access_token" => access_token} = token_map ->
        {:ok, access_token, token_map}

      _ ->
        {:error, :missing_gmail_token}
    end
  end

  defp refresh_access_token(_connection, token) do
    refresh_token = Map.get(token, "refresh_token")

    if is_nil(refresh_token) do
      {:error, :refresh_token_missing}
    else
      with {:ok, %{client_id: client_id, client_secret: client_secret}} <- oauth_config(),
           {:ok, refreshed} <-
             request_json(:post, @token_url,
               form: %{
                 "refresh_token" => refresh_token,
                 "client_id" => client_id,
                 "client_secret" => client_secret,
                 "grant_type" => "refresh_token"
               }
             ) do
        refreshed =
          refreshed
          |> normalize_token()
          |> Map.put("refresh_token", refresh_token)

        {:ok, Map.get(refreshed, "access_token"), refreshed}
      end
    end
  end

  defp list_messages(access_token, last_synced_at) do
    query = build_query(last_synced_at)

    params =
      if query do
        [q: query, maxResults: 25]
      else
        [maxResults: 25]
      end

    with {:ok, body} <-
           request_json(:get, "#{@gmail_api}/users/me/messages",
             headers: auth_headers(access_token),
             params: params
           ) do
      messages = Map.get(body, "messages") || []
      fetch_messages(access_token, messages)
    end
  end

  defp fetch_messages(_access_token, []), do: {:ok, []}

  defp fetch_messages(access_token, messages) do
    details =
      Enum.map(messages, fn %{"id" => id} ->
        case request_json(:get, "#{@gmail_api}/users/me/messages/#{id}",
               headers: auth_headers(access_token),
               params: [format: "metadata", metadataHeaders: ["From", "To", "Subject", "Date"]]
             ) do
          {:ok, body} -> {:ok, body}
          {:error, reason} -> {:error, {id, reason}}
        end
      end)

    {oks, errors} = Enum.split_with(details, &match?({:ok, _}, &1))

    if errors != [] do
      {:error, errors}
    else
      {:ok, Enum.map(oks, fn {:ok, body} -> body end)}
    end
  end

  defp ingest_messages(_connection, []), do: :ok

  defp ingest_messages(%ChannelConnection{} = connection, messages) do
    grouped = Enum.group_by(messages, &Map.get(&1, "threadId"))
    endpoint_address = connection.endpoint.address

    Enum.reduce_while(grouped, :ok, fn {_thread_id, items}, _acc ->
      {events, params} = build_thread_events(endpoint_address, items)

      case Ingestion.ingest_events(Map.put(params, "events", events)) do
        {:ok, _payload} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp build_thread_events(endpoint_address, messages) do
    sorted =
      Enum.sort_by(messages, fn message ->
        message_timestamp(message) |> DateTime.to_unix()
      end)

    first = List.first(sorted)
    {direction, customer_address, from_address} = message_parties(endpoint_address, first)

    params = %{
      "channel_key" => "email",
      "channel_type" => "email",
      "endpoint_address" => endpoint_address,
      "from_address" => from_address,
      "customer_address" => customer_address,
      "direction" => direction,
      "session_external_id" => Map.get(first, "threadId"),
      "started_at" => message_timestamp(first)
    }

    events =
      Enum.map(sorted, fn message ->
        {message_direction, _customer, _from} = message_parties(endpoint_address, message)

        %{
          "ts" => message_timestamp(message),
          "type" =>
            if(message_direction == "outbound",
              do: "channel.message.sent",
              else: "channel.message.received"
            ),
          "source" => "channel",
          "idempotency_key" => "gmail:#{Map.get(message, "id")}",
          "payload" => message_payload(message)
        }
      end)

    {events, params}
  end

  defp message_payload(message) do
    payload = %{
      "provider" => "gmail",
      "message_id" => Map.get(message, "id"),
      "thread_id" => Map.get(message, "threadId"),
      "snippet" => Map.get(message, "snippet")
    }

    headers = parse_headers(message)

    payload
    |> Map.put("subject", Map.get(headers, "subject"))
    |> Map.put("from", Map.get(headers, "from"))
    |> Map.put("to", Map.get(headers, "to"))
  end

  defp parse_headers(message) do
    headers = get_in(message, ["payload", "headers"]) || []

    headers
    |> Enum.reduce(%{}, fn header, acc ->
      name = header["name"] || ""
      value = header["value"] || ""
      Map.put(acc, String.downcase(name), value)
    end)
  end

  defp message_parties(endpoint_address, message) do
    headers = parse_headers(message)
    from_list = extract_emails(Map.get(headers, "from"))
    to_list = extract_emails(Map.get(headers, "to"))
    endpoint = String.downcase(endpoint_address)

    direction =
      if Enum.any?(from_list, &(String.downcase(&1) == endpoint)),
        do: "outbound",
        else: "inbound"

    customer_address =
      case direction do
        "outbound" -> List.first(to_list) || List.first(from_list)
        _ -> List.first(from_list) || List.first(to_list)
      end

    {direction, customer_address, List.first(from_list)}
  end

  defp message_timestamp(message) do
    case Map.get(message, "internalDate") do
      nil ->
        DateTime.utc_now()

      value ->
        value
        |> to_string()
        |> Integer.parse()
        |> case do
          {millis, _} -> DateTime.from_unix!(millis, :millisecond)
          _ -> DateTime.utc_now()
        end
    end
  end

  defp send_gmail(access_token, from, to, subject, text, thread_id) do
    raw =
      [
        "From: #{from}",
        "To: #{to}",
        "Subject: #{subject}",
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=UTF-8",
        "",
        text
      ]
      |> Enum.join("\r\n")

    payload = %{"raw" => Base.url_encode64(raw, padding: false)}
    payload = if thread_id, do: Map.put(payload, "threadId", thread_id), else: payload

    request_json(:post, "#{@gmail_api}/users/me/messages/send",
      headers: auth_headers(access_token),
      json: payload
    )
  end

  defp update_connection_status(%ChannelConnection{} = connection, status, metadata) do
    next_metadata = Map.merge(connection.metadata || %{}, metadata)

    connection
    |> ChannelConnection.changeset(%{status: status, metadata: next_metadata})
    |> Repo.update()

    :ok
  end

  defp update_token_secret(%ChannelConnection{} = connection, token) do
    case Jason.encode(token) do
      {:ok, json} ->
        _ =
          Secrets.upsert(
            Repo,
            connection.tenant_id,
            %{
              "provider" => connection.provider,
              "channel_id" => connection.channel_id,
              "endpoint_id" => connection.endpoint_id
            },
            json,
            connection
          )

        :ok

      {:error, _} ->
        :ok
    end
  end

  defp upsert_connection(tenant_id, channel, endpoint, token, profile) do
    existing = Channels.get_connection_by_endpoint(tenant_id, endpoint.id)
    token = merge_refresh_token(token, existing)
    metadata = connection_metadata(profile, token, existing)

    attrs = %{
      "channel_id" => channel.id,
      "endpoint_id" => endpoint.id,
      "provider" => :gmail,
      "status" => :active,
      "metadata" => metadata
    }

    {:ok, secret_value} = Jason.encode(token)

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:secret, fn repo, _ ->
        Secrets.upsert(repo, tenant_id, attrs, secret_value, existing)
      end)
      |> Ecto.Multi.run(:connection, fn repo, %{secret: secret} ->
        connection_attrs =
          attrs
          |> Secrets.put_secret_id(secret)
          |> Map.put("tenant_id", tenant_id)

        case existing do
          nil ->
            %ChannelConnection{}
            |> ChannelConnection.changeset(connection_attrs)
            |> repo.insert()

          %ChannelConnection{} = connection ->
            connection
            |> ChannelConnection.changeset(connection_attrs)
            |> repo.update()
        end
      end)

    case Repo.transaction(multi) do
      {:ok, %{connection: connection}} -> {:ok, connection}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp connection_metadata(profile, token, existing) do
    base = (existing && existing.metadata) || %{}

    base
    |> Map.put("profile", profile)
    |> Map.put("scopes", Map.get(token, "scope"))
  end

  defp merge_refresh_token(token, nil), do: token

  defp merge_refresh_token(token, %ChannelConnection{} = connection) do
    refresh_token = Map.get(token, "refresh_token") || existing_refresh_token(connection)

    if is_nil(refresh_token) do
      token
    else
      Map.put(token, "refresh_token", refresh_token)
    end
  end

  defp existing_refresh_token(connection) do
    connection
    |> read_token()
    |> Map.get("refresh_token")
  end

  defp read_token(%ChannelConnection{} = connection) do
    connection
    |> Secrets.get_secret_value()
    |> decode_json()
  end

  defp decode_json(nil), do: %{}

  defp decode_json(value) when is_map(value), do: value

  defp decode_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end

  defp normalize_token(token) when is_map(token) do
    token = stringify_keys(token)
    expires_in = Map.get(token, "expires_in")

    token =
      if is_integer(expires_in) do
        expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)
        Map.put(token, "expires_at", DateTime.to_iso8601(expires_at))
      else
        token
      end

    token
  end

  defp normalize_token(token), do: token

  defp token_expired?(expires_at) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, dt, _offset} -> DateTime.compare(dt, DateTime.utc_now()) == :lt
      _ -> true
    end
  end

  defp token_expired?(_), do: true

  defp auth_headers(access_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"accept", "application/json"}
    ]
  end

  defp request_json(method, url, opts) do
    opts = Keyword.merge([method: method, url: url, http_errors: :return], opts)

    case client().request(opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, error} ->
        {:error, error}
    end
  end

  defp build_query(nil) do
    after_ts = DateTime.add(DateTime.utc_now(), -7 * 86_400, :second)
    "after:#{DateTime.to_unix(after_ts)}"
  end

  defp build_query(%DateTime{} = last_synced_at) do
    "after:#{DateTime.to_unix(last_synced_at)}"
  end

  defp build_query(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> "after:#{DateTime.to_unix(dt)}"
      _ -> build_query(nil)
    end
  end

  defp build_query(_value), do: build_query(nil)

  defp extract_emails(nil), do: []

  defp extract_emails(value) do
    value
    |> to_string()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn part ->
      case Regex.run(~r/<([^>]+)>/, part) do
        [_, email] -> [String.trim(email)]
        _ -> [String.trim(part, "\"")]
      end
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp oauth_config do
    config = Application.get_env(:swati, :gmail_oauth, %{})
    client_id = Map.get(config, :client_id) || Map.get(config, "client_id")
    client_secret = Map.get(config, :client_secret) || Map.get(config, "client_secret")

    if is_binary(client_id) and is_binary(client_secret) do
      {:ok, %{client_id: client_id, client_secret: client_secret}}
    else
      {:error, :missing_gmail_oauth_config}
    end
  end

  defp client do
    Application.get_env(:swati, :gmail_client, Swati.Channels.Gmail.ClientReq)
  end
end
