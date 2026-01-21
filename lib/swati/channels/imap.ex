defmodule Swati.Channels.Imap do
  alias Ecto.Changeset
  alias Swati.Channels
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Ingestion
  alias Swati.Channels.Secrets
  alias Swati.Repo

  @default_imap_port 993
  @default_smtp_port 587

  @required_fields [:email_address, :imap_host, :imap_username, :imap_password]
  def default_params(preset \\ :custom) do
    base = %{
      "imap_port" => @default_imap_port,
      "imap_ssl" => true,
      "smtp_port" => @default_smtp_port,
      "smtp_ssl" => false
    }

    case preset do
      :zoho ->
        Map.merge(base, %{
          "provider_label" => "Zoho Mail",
          "imap_host" => "imap.zoho.com",
          "smtp_host" => "smtp.zoho.com"
        })

      _ ->
        base
    end
  end

  def changeset(attrs \\ %{}) do
    types = %{
      email_address: :string,
      display_name: :string,
      provider_label: :string,
      imap_host: :string,
      imap_port: :integer,
      imap_ssl: :boolean,
      imap_username: :string,
      imap_password: :string,
      smtp_host: :string,
      smtp_port: :integer,
      smtp_ssl: :boolean,
      smtp_username: :string,
      smtp_password: :string
    }

    {%{}, types}
    |> Changeset.cast(attrs, Map.keys(types))
    |> Changeset.validate_required(@required_fields)
    |> Changeset.validate_format(:email_address, ~r/@/)
    |> Changeset.validate_number(:imap_port, greater_than: 0)
    |> Changeset.validate_number(:smtp_port, greater_than: 0)
  end

  def connect(tenant_id, attrs, opts \\ []) do
    changeset = changeset(attrs)

    if changeset.valid? do
      params =
        changeset
        |> Changeset.apply_changes()
        |> normalize_params()

      verify? = Keyword.get(opts, :verify?, true)

      endpoint_attrs =
        %{"metadata" => %{"provider" => "imap"}}
        |> maybe_put_display_name(params.display_name)

      with :ok <- maybe_verify_imap(params, verify?),
           {:ok, channel} <- Channels.ensure_email_channel(tenant_id),
           {:ok, endpoint} <-
             Channels.ensure_endpoint(tenant_id, channel.id, params.email_address, endpoint_attrs),
           {:ok, connection} <- upsert_connection(tenant_id, channel, endpoint, params) do
        {:ok, connection}
      else
        {:error, %Changeset{}} = error -> error
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, changeset}
    end
  end

  def sync_connection(%ChannelConnection{} = connection) do
    connection = Repo.preload(connection, [:endpoint, :channel])

    with {:ok, creds} <- read_credentials(connection),
         {:ok, messages} <- fetch_messages(creds, connection),
         :ok <- ingest_messages(connection, messages) do
      last_uid = max_uid(messages)

      next_metadata =
        connection.metadata
        |> Kernel.||(%{})
        |> Map.new()
        |> maybe_put_last_uid(last_uid)

      connection
      |> ChannelConnection.changeset(%{
        last_synced_at: DateTime.utc_now(),
        status: :active,
        metadata: next_metadata
      })
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
      with {:ok, creds} <- read_credentials(connection),
           {:ok, response} <-
             send_smtp(connection.endpoint.address, to, subject, text, thread_id, creds) do
        {:ok, response}
      end
    end
  end

  defp maybe_verify_imap(_params, false), do: :ok

  defp maybe_verify_imap(params, true) do
    imap = params.imap

    with {:ok, identifier} <- open_imap_connection(imap),
         :ok <- ensure_ok(client().login(identifier, imap.username, imap.password)),
         :ok <- ensure_ok(client().select(identifier, "INBOX")) do
      _ = client().logout(identifier)
      :ok
    else
      {:error, reason} ->
        {:error, reason}

      error ->
        {:error, error}
    end
  end

  defp open_imap_connection(%{host: host, port: port, ssl: true}) do
    case client().start_connection_ssl(host, port) do
      {:ok, {identifier, _greeting}} -> {:ok, identifier}
      {:error, _} = error -> error
    end
  end

  defp open_imap_connection(%{host: host, port: port, ssl: false}) do
    case client().start_connection(host, port) do
      {:ok, {identifier, _greeting}} -> {:ok, identifier}
      {:error, _} = error -> error
    end
  end

  defp fetch_messages(creds, connection) do
    imap = creds.imap

    with {:ok, identifier} <- open_imap_connection(imap),
         :ok <- ensure_ok(client().login(identifier, imap.username, imap.password)),
         :ok <- ensure_ok(client().select(identifier, "INBOX")),
         {:ok, uids} <- search_uids(identifier, connection),
         {:ok, messages} <- fetch_uids(identifier, uids) do
      _ = client().logout(identifier)
      {:ok, messages}
    end
  end

  defp search_uids(identifier, connection) do
    criteria = search_criteria(connection)

    case client().uid_search(identifier, criteria) do
      {:error, _} = error ->
        error

      result ->
        uids =
          result
          |> extract_payload()
          |> collect_tag_values(:search)
          |> List.flatten()
          |> Enum.filter(&is_integer/1)
          |> Enum.sort()
          |> Enum.take(-25)

        {:ok, uids}
    end
  end

  defp search_criteria(connection) do
    metadata = connection.metadata || %{}

    case Map.get(metadata, "last_uid") do
      last_uid when is_integer(last_uid) and last_uid > 0 ->
        "UID #{last_uid + 1}:*"

      _ ->
        case connection.last_synced_at do
          %DateTime{} = last_synced_at ->
            "SINCE #{imap_date(last_synced_at)}"

          _ ->
            "ALL"
        end
    end
  end

  defp fetch_uids(_identifier, []), do: {:ok, []}

  defp fetch_uids(identifier, uids) do
    messages =
      Enum.flat_map(uids, fn uid ->
        case client().uid_fetch(identifier, uid, uid, "UID ENVELOPE INTERNALDATE", 50_000) do
          {:error, _reason} ->
            []

          result ->
            result
            |> extract_payload()
            |> extract_message_maps()
            |> Enum.map(&message_from_map/1)
        end
      end)

    {:ok, messages}
  end

  defp extract_message_maps(payload) do
    payload
    |> List.wrap()
    |> Enum.flat_map(&collect_maps/1)
    |> Enum.filter(fn map ->
      is_map(map) and
        (map_has_tag?(map, :uid) or map_has_tag?(map, :"message-number") or
           map_has_tag?(map, :message_number))
    end)
  end

  defp collect_maps(map) when is_map(map), do: [map]
  defp collect_maps(list) when is_list(list), do: Enum.flat_map(list, &collect_maps/1)
  defp collect_maps({_tag, value}), do: collect_maps(value)
  defp collect_maps(_), do: []

  defp message_from_map(map) do
    uid = fetch_map_value(map, :uid) || fetch_map_value(map, :uniqueid)

    %{
      uid: uid,
      subject: fetch_map_value(map, :subject),
      message_id: fetch_map_value(map, :"message-id"),
      in_reply_to: fetch_map_value(map, :"in-reply-to"),
      date: fetch_map_value(map, :internal_date) || fetch_map_value(map, :date),
      from: addresses_from_value(fetch_map_value(map, :from)),
      to: addresses_from_value(fetch_map_value(map, :to))
    }
  end

  defp fetch_map_value(map, key) do
    target = normalize_tag(key)

    map
    |> Enum.find_value(fn {k, v} ->
      if normalize_tag(k) == target do
        extract_scalar(v)
      else
        nil
      end
    end)
  end

  defp map_has_tag?(map, key) do
    target = normalize_tag(key)

    Enum.any?(map, fn {k, _v} ->
      normalize_tag(k) == target
    end)
  end

  defp extract_scalar([value | _]), do: extract_scalar(value)
  defp extract_scalar(value), do: value

  defp addresses_from_value(nil), do: []

  defp addresses_from_value(value) do
    value
    |> List.wrap()
    |> Enum.flat_map(&collect_address_maps/1)
    |> Enum.map(&format_address/1)
    |> Enum.filter(&is_binary/1)
  end

  defp collect_address_maps(map) when is_map(map), do: [map]

  defp collect_address_maps(list) when is_list(list),
    do: Enum.flat_map(list, &collect_address_maps/1)

  defp collect_address_maps({_tag, value}), do: collect_address_maps(value)
  defp collect_address_maps(_), do: []

  defp format_address(map) do
    mailbox = extract_scalar(Map.get(map, :mailbox) || Map.get(map, "mailbox"))
    host = extract_scalar(Map.get(map, :host) || Map.get(map, "host"))
    name = extract_scalar(Map.get(map, :name) || Map.get(map, "name"))

    if is_binary(mailbox) and is_binary(host) do
      email = mailbox <> "@" <> host

      if is_binary(name) and name != "" do
        "#{name} <#{email}>"
      else
        email
      end
    end
  end

  defp ingest_messages(_connection, []), do: :ok

  defp ingest_messages(%ChannelConnection{} = connection, messages) do
    grouped = Enum.group_by(messages, &thread_id/1)
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
      "session_external_id" => thread_id(first),
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
          "idempotency_key" => "imap:#{message.uid}",
          "payload" => message_payload(message)
        }
      end)

    {events, params}
  end

  defp thread_id(message) do
    message.in_reply_to || message.message_id || "imap:#{message.uid}"
  end

  defp message_payload(message) do
    %{
      "provider" => "imap",
      "message_id" => message.message_id,
      "thread_id" => thread_id(message),
      "subject" => message.subject,
      "from" => List.first(message.from),
      "to" => message.to
    }
  end

  defp message_parties(endpoint_address, message) do
    from_address = extract_email(List.first(message.from))
    to_list = message.to
    endpoint = String.downcase(endpoint_address)

    direction =
      if is_binary(from_address) and String.downcase(from_address) == endpoint,
        do: "outbound",
        else: "inbound"

    customer_address =
      case direction do
        "outbound" -> extract_email(List.first(to_list)) || from_address
        _ -> from_address || extract_email(List.first(to_list))
      end

    {direction, customer_address, from_address}
  end

  defp message_timestamp(message) do
    case message.date do
      %DateTime{} = dt -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp extract_email(nil), do: nil

  defp extract_email(value) when is_binary(value) do
    case Regex.run(~r/<([^>]+)>/, value) do
      [_, email] -> String.trim(email)
      _ -> value
    end
  end

  defp send_smtp(from, to, subject, text, thread_id, creds) do
    smtp = creds.smtp
    raw = build_raw_message(from, to, subject, text, thread_id)

    opts = [
      relay: smtp.host,
      port: smtp.port,
      username: smtp.username,
      password: smtp.password,
      ssl: smtp.ssl,
      tls: smtp_tls_mode(smtp.ssl),
      auth: smtp_auth_mode(smtp.username, smtp.password)
    ]

    case :gen_smtp_client.send_blocking({from, [to], raw}, opts) do
      {:ok, _} = ok -> ok
      {:error, _} = error -> error
      other -> {:ok, other}
    end
  end

  defp build_raw_message(from, to, subject, text, thread_id) do
    now = DateTime.utc_now()
    message_id = new_message_id(from)

    headers =
      [
        "From: #{from}",
        "To: #{to}",
        "Subject: #{subject}",
        "Date: #{Calendar.strftime(now, "%a, %d %b %Y %H:%M:%S %z")}",
        "Message-ID: #{message_id}",
        "MIME-Version: 1.0",
        "Content-Type: text/plain; charset=UTF-8"
      ]
      |> maybe_thread_headers(thread_id)

    (headers ++ ["", text])
    |> Enum.join("\r\n")
  end

  defp maybe_thread_headers(headers, nil), do: headers
  defp maybe_thread_headers(headers, ""), do: headers

  defp maybe_thread_headers(headers, thread_id) do
    headers ++ ["In-Reply-To: #{thread_id}", "References: #{thread_id}"]
  end

  defp new_message_id(from) do
    domain =
      case String.split(from, "@") do
        [_user, host] -> host
        _ -> "localhost"
      end

    "<#{Ecto.UUID.generate()}@#{domain}>"
  end

  defp smtp_tls_mode(true), do: :never
  defp smtp_tls_mode(false), do: :always

  defp smtp_auth_mode(username, password) do
    if is_binary(username) and is_binary(password) do
      :always
    else
      :never
    end
  end

  defp read_credentials(%ChannelConnection{} = connection) do
    connection
    |> Secrets.get_secret_value()
    |> decode_json()
    |> case do
      %{"imap" => imap, "smtp" => smtp} -> {:ok, %{imap: imap, smtp: smtp}}
      _ -> {:error, :imap_credentials_missing}
    end
  end

  defp decode_json(nil), do: %{}

  defp decode_json(value) when is_map(value), do: value

  defp decode_json(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} -> decoded
      _ -> %{}
    end
  end

  defp normalize_params(params) do
    email = Map.get(params, :email_address)
    display_name = blank_to_nil(Map.get(params, :display_name))
    provider_label = blank_to_nil(Map.get(params, :provider_label))

    imap_host = Map.get(params, :imap_host)
    imap_port = Map.get(params, :imap_port) || @default_imap_port
    imap_ssl = Map.get(params, :imap_ssl)
    imap_ssl = if is_boolean(imap_ssl), do: imap_ssl, else: true
    imap_username = Map.get(params, :imap_username)
    imap_password = Map.get(params, :imap_password)

    smtp_host = blank_to_nil(Map.get(params, :smtp_host)) || imap_host
    smtp_port = Map.get(params, :smtp_port) || @default_smtp_port
    smtp_ssl = Map.get(params, :smtp_ssl)
    smtp_ssl = if is_boolean(smtp_ssl), do: smtp_ssl, else: false
    smtp_username = blank_to_nil(Map.get(params, :smtp_username)) || imap_username
    smtp_password = blank_to_nil(Map.get(params, :smtp_password)) || imap_password

    %{
      email_address: email,
      display_name: display_name,
      provider_label: provider_label,
      imap: %{
        host: imap_host,
        port: imap_port,
        ssl: imap_ssl,
        username: imap_username,
        password: imap_password
      },
      smtp: %{
        host: smtp_host,
        port: smtp_port,
        ssl: smtp_ssl,
        username: smtp_username,
        password: smtp_password
      }
    }
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp maybe_put_display_name(attrs, nil), do: attrs
  defp maybe_put_display_name(attrs, ""), do: attrs

  defp maybe_put_display_name(attrs, display_name),
    do: Map.put(attrs, "display_name", display_name)

  defp upsert_connection(tenant_id, channel, endpoint, params) do
    existing = Channels.get_connection_by_endpoint(tenant_id, endpoint.id)

    metadata =
      (existing && existing.metadata) ||
        %{}
        |> Map.put("provider_label", params.provider_label)
        |> Map.put("imap", %{
          "host" => params.imap.host,
          "port" => params.imap.port,
          "ssl" => params.imap.ssl
        })
        |> Map.put("smtp", %{
          "host" => params.smtp.host,
          "port" => params.smtp.port,
          "ssl" => params.smtp.ssl
        })

    attrs = %{
      "channel_id" => channel.id,
      "endpoint_id" => endpoint.id,
      "provider" => :imap,
      "status" => :active,
      "metadata" => metadata
    }

    {:ok, secret_value} = Jason.encode(%{"imap" => params.imap, "smtp" => params.smtp})

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

  defp update_connection_status(%ChannelConnection{} = connection, status, metadata) do
    next_metadata = Map.merge(connection.metadata || %{}, metadata)

    connection
    |> ChannelConnection.changeset(%{status: status, metadata: next_metadata})
    |> Repo.update()

    :ok
  end

  defp extract_payload({status, payload}) when status in [:ok, :no, :bad], do: payload
  defp extract_payload(%{payload: payload}), do: payload
  defp extract_payload(payload), do: payload

  defp collect_tag_values(term, target) do
    cond do
      is_tuple(term) ->
        {tag, value} = term

        if normalize_tag(tag) == normalize_tag(target) do
          [value | collect_tag_values(value, target)]
        else
          collect_tag_values(value, target)
        end

      is_map(term) ->
        Enum.flat_map(term, fn {k, v} ->
          if normalize_tag(k) == normalize_tag(target) do
            [v | collect_tag_values(v, target)]
          else
            collect_tag_values(v, target)
          end
        end)

      is_list(term) ->
        Enum.flat_map(term, &collect_tag_values(&1, target))

      true ->
        []
    end
  end

  defp normalize_tag(tag) when is_atom(tag) do
    tag |> Atom.to_string() |> normalize_tag()
  end

  defp normalize_tag(tag) when is_binary(tag) do
    tag
    |> String.downcase()
    |> String.replace("-", "")
    |> String.replace("_", "")
  end

  defp normalize_tag(tag) do
    tag |> to_string() |> normalize_tag()
  end

  defp ensure_ok({status, payload, _rest}) when is_atom(status) or is_binary(status) do
    ensure_ok({status, payload})
  end

  defp ensure_ok({status, payload}) when is_atom(status) or is_binary(status) do
    case normalize_status(status) do
      :ok -> :ok
      :no -> {:error, {:imap_no, payload}}
      :bad -> {:error, {:imap_bad, payload}}
      :error -> {:error, {:imap_error, payload}}
      _ -> {:error, {:imap_error, {status, payload}}}
    end
  end

  defp ensure_ok({:error, _} = error), do: error
  defp ensure_ok(result), do: {:error, {:imap_error, result}}

  defp normalize_status(status) do
    case status |> to_string() |> String.downcase() do
      "ok" -> :ok
      "no" -> :no
      "bad" -> :bad
      "error" -> :error
      _ -> status
    end
  end

  defp imap_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d-%b-%Y")
  end

  defp max_uid(messages) do
    messages
    |> Enum.map(& &1.uid)
    |> Enum.filter(&is_integer/1)
    |> Enum.max(fn -> nil end)
  end

  defp maybe_put_last_uid(metadata, nil), do: metadata
  defp maybe_put_last_uid(metadata, last_uid), do: Map.put(metadata, "last_uid", last_uid)

  defp client do
    Application.get_env(:swati, :imap_client, Swati.Channels.Imap.ClientExImap)
  end
end
