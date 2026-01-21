defmodule Swati.Channels.Outlook do
  alias Swati.Channels
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Ingestion
  alias Swati.Channels.Secrets
  alias Swati.Repo

  @auth_base "https://login.microsoftonline.com"
  @graph_api "https://graph.microsoft.com/v1.0"

  @scopes [
    "openid",
    "email",
    "profile",
    "offline_access",
    "https://graph.microsoft.com/Mail.Read",
    "https://graph.microsoft.com/Mail.Send"
  ]

  def authorization_url(state, redirect_uri) do
    with {:ok, %{client_id: client_id, tenant: tenant}} <- oauth_config(),
         true <- is_binary(redirect_uri) do
      params = %{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "response_mode" => "query",
        "prompt" => "consent",
        "scope" => Enum.join(@scopes, " "),
        "state" => state
      }

      {:ok, auth_url(tenant) <> "?" <> URI.encode_query(params)}
    else
      _ -> {:error, :missing_outlook_oauth_config}
    end
  end

  def connect(tenant_id, code, redirect_uri) do
    with {:ok, token} <- exchange_code(code, redirect_uri),
         token <- normalize_token(token),
         {:ok, profile} <- fetch_profile(Map.get(token, "access_token")),
         email when is_binary(email) <- profile_email(profile),
         {:ok, channel} <- Channels.ensure_email_channel(tenant_id),
         {:ok, endpoint} <-
           Channels.ensure_endpoint(tenant_id, channel.id, email, %{
             "metadata" => %{"provider" => "outlook"}
           }),
         {:ok, connection} <- upsert_connection(tenant_id, channel, endpoint, token, profile) do
      {:ok, connection}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :outlook_profile_missing}
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

    if is_nil(to) or text == "" do
      {:error, :message_payload_invalid}
    else
      with {:ok, access_token, token} <- ensure_access_token(connection),
           {:ok, response} <- send_outlook(access_token, to, subject, text) do
        :ok = update_token_secret(connection, token)
        {:ok, response}
      end
    end
  end

  defp exchange_code(code, redirect_uri) do
    with {:ok, %{client_id: client_id, client_secret: client_secret, tenant: tenant}} <-
           oauth_config() do
      params = %{
        "code" => code,
        "client_id" => client_id,
        "client_secret" => client_secret,
        "redirect_uri" => redirect_uri,
        "grant_type" => "authorization_code"
      }

      request_json(:post, token_url(tenant), form: params)
    end
  end

  defp fetch_profile(nil), do: {:error, :missing_access_token}

  defp fetch_profile(access_token) do
    request_json(:get, "#{@graph_api}/me", headers: auth_headers(access_token))
  end

  defp profile_email(profile) do
    Map.get(profile, "mail") || Map.get(profile, "userPrincipalName")
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
        {:error, :missing_outlook_token}
    end
  end

  defp refresh_access_token(_connection, token) do
    refresh_token = Map.get(token, "refresh_token")

    if is_nil(refresh_token) do
      {:error, :refresh_token_missing}
    else
      with {:ok, %{client_id: client_id, client_secret: client_secret, tenant: tenant}} <-
             oauth_config(),
           {:ok, refreshed} <-
             request_json(:post, token_url(tenant),
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
    params =
      %{
        "$top" => "25",
        "$orderby" => "receivedDateTime desc",
        "$select" =>
          "id,conversationId,receivedDateTime,sentDateTime,from,toRecipients,subject,bodyPreview"
      }
      |> maybe_filter_since(last_synced_at)

    with {:ok, body} <-
           request_json(:get, "#{@graph_api}/me/messages",
             headers: auth_headers(access_token),
             params: params
           ) do
      {:ok, Map.get(body, "value") || []}
    end
  end

  defp ingest_messages(_connection, []), do: :ok

  defp ingest_messages(%ChannelConnection{} = connection, messages) do
    grouped = Enum.group_by(messages, &Map.get(&1, "conversationId"))
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
      "session_external_id" => Map.get(first, "conversationId") || Map.get(first, "id"),
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
          "idempotency_key" => "outlook:#{Map.get(message, "id")}",
          "payload" => message_payload(message)
        }
      end)

    {events, params}
  end

  defp message_payload(message) do
    payload = %{
      "provider" => "outlook",
      "message_id" => Map.get(message, "id"),
      "thread_id" => Map.get(message, "conversationId"),
      "snippet" => Map.get(message, "bodyPreview"),
      "subject" => Map.get(message, "subject")
    }

    payload
    |> Map.put("from", address_from(Map.get(message, "from")))
    |> Map.put("to", addresses_from(Map.get(message, "toRecipients")))
  end

  defp message_parties(endpoint_address, message) do
    from_address = address_from(Map.get(message, "from"))
    to_list = addresses_from(Map.get(message, "toRecipients"))
    endpoint = String.downcase(endpoint_address)

    direction =
      if is_binary(from_address) and String.downcase(from_address) == endpoint,
        do: "outbound",
        else: "inbound"

    customer_address =
      case direction do
        "outbound" -> List.first(to_list) || from_address
        _ -> from_address || List.first(to_list)
      end

    {direction, customer_address, from_address}
  end

  defp address_from(nil), do: nil

  defp address_from(%{"emailAddress" => %{"address" => address}}), do: address

  defp address_from(_value), do: nil

  defp addresses_from(nil), do: []

  defp addresses_from(list) when is_list(list) do
    list
    |> Enum.map(&address_from/1)
    |> Enum.filter(&is_binary/1)
  end

  defp addresses_from(_value), do: []

  defp message_timestamp(message) do
    timestamp = Map.get(message, "receivedDateTime") || Map.get(message, "sentDateTime")

    case timestamp do
      nil ->
        DateTime.utc_now()

      value ->
        case DateTime.from_iso8601(value) do
          {:ok, dt, _offset} -> dt
          _ -> DateTime.utc_now()
        end
    end
  end

  defp send_outlook(access_token, to, subject, text) do
    payload = %{
      "message" => %{
        "subject" => subject,
        "body" => %{"contentType" => "Text", "content" => text},
        "toRecipients" => [%{"emailAddress" => %{"address" => to}}]
      }
    }

    request_json(:post, "#{@graph_api}/me/sendMail",
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
      "provider" => :outlook,
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

    expires_in =
      case Map.get(token, "expires_in") do
        value when is_integer(value) ->
          value

        value when is_binary(value) ->
          case Integer.parse(value) do
            {int, _} -> int
            _ -> nil
          end

        _ ->
          nil
      end

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

  defp maybe_filter_since(params, nil), do: params

  defp maybe_filter_since(params, %DateTime{} = last_synced_at) do
    Map.put(params, "$filter", "receivedDateTime ge #{DateTime.to_iso8601(last_synced_at)}")
  end

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp oauth_config do
    config = Application.get_env(:swati, :outlook_oauth, %{})
    client_id = Map.get(config, :client_id) || Map.get(config, "client_id")
    client_secret = Map.get(config, :client_secret) || Map.get(config, "client_secret")
    tenant = Map.get(config, :tenant) || Map.get(config, "tenant") || "common"

    if is_binary(client_id) and is_binary(client_secret) do
      {:ok, %{client_id: client_id, client_secret: client_secret, tenant: tenant}}
    else
      {:error, :missing_outlook_oauth_config}
    end
  end

  defp auth_url(tenant), do: "#{@auth_base}/#{tenant}/oauth2/v2.0/authorize"
  defp token_url(tenant), do: "#{@auth_base}/#{tenant}/oauth2/v2.0/token"

  defp client do
    Application.get_env(:swati, :outlook_client, Swati.Channels.Outlook.ClientReq)
  end
end
