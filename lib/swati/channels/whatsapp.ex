defmodule Swati.Channels.WhatsApp do
  alias Swati.Channels
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Queries
  alias Swati.Channels.Secrets
  alias Swati.Channels.WhatsApp.MetaClient
  alias Swati.Channels.WhatsApp.WebhookProcessor
  alias Swati.Repo

  @refresh_threshold_days 10

  def config do
    config = Application.get_env(:swati, :whatsapp, %{})

    %{
      app_id: value_from_config(config, :app_id),
      app_secret: value_from_config(config, :app_secret),
      config_id: value_from_config(config, :config_id),
      graph_api_version: value_from_config(config, :graph_api_version) || "v21.0",
      webhook_verify_token: value_from_config(config, :webhook_verify_token),
      webhook_callback_url: value_from_config(config, :webhook_callback_url)
    }
  end

  def configured?(config \\ nil) do
    config = config || config()

    required = [config.app_id, config.app_secret, config.config_id]
    Enum.all?(required, &is_binary/1)
  end

  def missing_config(config \\ nil) do
    config = config || config()

    missing = []
    missing = if is_binary(config.app_id), do: missing, else: missing ++ ["META_APP_ID"]
    missing = if is_binary(config.app_secret), do: missing, else: missing ++ ["META_APP_SECRET"]
    missing = if is_binary(config.config_id), do: missing, else: missing ++ ["META_CONFIG_ID"]

    missing
  end

  def connect_embedded_signup(tenant_id, auth_code) when is_binary(auth_code) do
    if configured?() do
      config = config()

      with {:ok, token} <- MetaClient.exchange_code_for_token(auth_code, config),
           token <- normalize_token(token),
           {:ok, debug_info} <- MetaClient.debug_token(token["access_token"], config),
           {:ok, waba_id} <- extract_waba_id(debug_info),
           {:ok, phone_numbers} <-
             MetaClient.list_phone_numbers(waba_id, token["access_token"], config),
           :ok <- ensure_webhook_subscription(waba_id, token["access_token"], config),
           {:ok, channel} <- Channels.ensure_whatsapp_channel(tenant_id),
           {:ok, secret} <- upsert_token_secret(tenant_id, waba_id, token),
           {:ok, connections} <-
             upsert_phone_numbers(tenant_id, channel, waba_id, phone_numbers, secret.id) do
        {:ok, connections}
      end
    else
      {:error, :whatsapp_config_missing}
    end
  end

  def refresh_phone_numbers(tenant_id, connection_id) do
    connection = Channels.get_connection!(tenant_id, connection_id) |> Repo.preload(:channel)

    if connection.provider == :whatsapp do
      with true <- not is_nil(connection.auth_secret_id) || {:error, :missing_whatsapp_token},
           {:ok, token} <- fetch_token(connection),
           {:ok, waba_id} <- waba_id_from_connection(connection),
           {:ok, phone_numbers} <-
             MetaClient.list_phone_numbers(waba_id, token["access_token"], config()),
           {:ok, channel} <- Channels.ensure_whatsapp_channel(tenant_id),
           {:ok, connections} <-
             upsert_phone_numbers(
               tenant_id,
               channel,
               waba_id,
               phone_numbers,
               connection.auth_secret_id
             ) do
        {:ok, connections}
      end
    else
      {:error, :not_whatsapp_connection}
    end
  end

  def handle_webhook(params), do: WebhookProcessor.handle_webhook(params)

  def send_message(%ChannelConnection{} = connection, attrs) when is_map(attrs) do
    connection = Repo.preload(connection, [:endpoint])

    with {:ok, token} <- ensure_access_token(connection),
         {:ok, phone_number_id} <- phone_number_id_from_connection(connection),
         {:ok, payload} <- build_send_payload(attrs),
         {:ok, response} <-
           MetaClient.send_message(phone_number_id, token["access_token"], payload, config()) do
      :ok = update_token_secret(connection, token)
      {:ok, response}
    end
  end

  def refresh_tokens do
    if configured?() do
      connections = Queries.list_whatsapp_connections()

      connections
      |> Enum.reject(&is_nil(&1.auth_secret_id))
      |> Enum.group_by(& &1.auth_secret_id)
      |> Enum.each(fn {_secret_id, grouped} ->
        refresh_secret_tokens(grouped)
      end)

      :ok
    else
      :ok
    end
  end

  def token_expiring_soon?(token) do
    expires_at = Map.get(token, "expires_at")

    case parse_datetime(expires_at) do
      {:ok, dt} ->
        threshold = DateTime.add(DateTime.utc_now(), @refresh_threshold_days, :day)
        DateTime.compare(dt, threshold) != :gt

      _ ->
        true
    end
  end

  defp refresh_secret_tokens([connection | _] = connections) do
    with {:ok, token} <- fetch_token(connection) do
      if token_expiring_soon?(token) do
        case MetaClient.refresh_token(token["access_token"], config()) do
          {:ok, refreshed} ->
            refreshed = normalize_token(refreshed)
            :ok = update_token_secret(connection, refreshed)
            update_connections_status(connections, :active, %{"reauth_required" => false})

          {:error, reason} ->
            update_connections_status(connections, :error, %{
              "reauth_required" => true,
              "refresh_error" => inspect(reason)
            })
        end
      end
    end
  end

  defp refresh_secret_tokens([]), do: :ok

  defp update_connections_status(connections, status, metadata) do
    Enum.each(connections, fn connection ->
      attrs = %{
        status: status,
        metadata: Map.merge(connection.metadata || %{}, metadata)
      }

      connection
      |> ChannelConnection.changeset(attrs)
      |> Repo.update()
    end)
  end

  defp update_connection_metadata(%ChannelConnection{} = connection, metadata) do
    attrs = %{metadata: Map.merge(connection.metadata || %{}, metadata)}

    connection
    |> ChannelConnection.changeset(attrs)
    |> Repo.update()
  end

  defp upsert_phone_numbers(tenant_id, channel, waba_id, %{"data" => phones}, secret_id)
       when is_list(phones) do
    upsert_phone_numbers(tenant_id, channel, waba_id, phones, secret_id)
  end

  defp upsert_phone_numbers(_tenant_id, _channel, _waba_id, [], _secret_id) do
    {:error, :no_phone_numbers}
  end

  defp upsert_phone_numbers(tenant_id, channel, waba_id, phones, secret_id) do
    Enum.reduce_while(phones, {:ok, []}, fn phone, {:ok, acc} ->
      case upsert_phone_number(tenant_id, channel, waba_id, phone, secret_id) do
        {:ok, connection} -> {:cont, {:ok, [connection | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, connections} -> {:ok, Enum.reverse(connections)}
      error -> error
    end
  end

  defp upsert_phone_number(tenant_id, channel, waba_id, phone, secret_id) do
    phone_number_id = Map.get(phone, "id")
    display_phone_number = Map.get(phone, "display_phone_number")

    address =
      normalize_phone_number(display_phone_number) ||
        if is_binary(phone_number_id), do: "whatsapp:#{phone_number_id}"

    if is_nil(address) do
      {:error, :phone_number_missing}
    else
      metadata = %{
        "provider" => "whatsapp",
        "waba_id" => waba_id,
        "phone_number_id" => phone_number_id,
        "display_phone_number" => display_phone_number,
        "verified_name" => Map.get(phone, "verified_name"),
        "quality_rating" => Map.get(phone, "quality_rating"),
        "status" => Map.get(phone, "status")
      }

      with {:ok, endpoint} <-
             Channels.ensure_endpoint(tenant_id, channel.id, address, %{
               "display_name" => Map.get(phone, "verified_name") || display_phone_number,
               "metadata" => metadata
             }) do
        existing = Channels.get_connection_by_endpoint(tenant_id, endpoint.id)

        connection_attrs = %{
          "tenant_id" => tenant_id,
          "channel_id" => channel.id,
          "endpoint_id" => endpoint.id,
          "provider" => :whatsapp,
          "status" => :active,
          "auth_secret_id" => secret_id,
          "metadata" => Map.put(metadata, "provider_label", "WhatsApp")
        }

        case existing do
          nil ->
            %ChannelConnection{}
            |> ChannelConnection.changeset(connection_attrs)
            |> Repo.insert()

          %ChannelConnection{} = connection ->
            connection
            |> ChannelConnection.changeset(connection_attrs)
            |> Repo.update()
        end
      end
    end
  end

  defp ensure_webhook_subscription(waba_id, access_token, config) do
    case MetaClient.subscribe_app(waba_id, access_token, config) do
      {:ok, %{"success" => true}} -> :ok
      {:ok, _body} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_waba_id(%{"data" => %{"granular_scopes" => scopes}}) when is_list(scopes) do
    scope = Enum.find(scopes, &(&1["scope"] == "whatsapp_business_management"))

    case scope do
      %{"target_ids" => [waba_id | _]} -> {:ok, waba_id}
      _ -> {:error, :no_waba_found}
    end
  end

  defp extract_waba_id(%{"data" => %{"granular_scopes" => scopes}}) when is_map(scopes) do
    case Map.get(scopes, "whatsapp_business_management") do
      %{"target_ids" => [waba_id | _]} -> {:ok, waba_id}
      _ -> {:error, :no_waba_found}
    end
  end

  defp extract_waba_id(_payload), do: {:error, :no_waba_found}

  defp upsert_token_secret(tenant_id, waba_id, token) do
    with {:ok, json} <- Jason.encode(token),
         {:ok, secret} <- Secrets.upsert_named(Repo, tenant_id, secret_name(waba_id), json) do
      {:ok, secret}
    end
  end

  defp ensure_access_token(connection) do
    with {:ok, token} <- fetch_token(connection) do
      if token_expired?(Map.get(token, "expires_at")) do
        refresh_access_token(connection, token)
      else
        {:ok, token}
      end
    end
  end

  defp refresh_access_token(connection, token) do
    case MetaClient.refresh_token(token["access_token"], config()) do
      {:ok, refreshed} ->
        refreshed = normalize_token(refreshed)
        :ok = update_token_secret(connection, refreshed)
        {:ok, refreshed}

      {:error, reason} ->
        update_connection_metadata(connection, %{"reauth_required" => true})
        {:error, reason}
    end
  end

  defp update_token_secret(%ChannelConnection{} = connection, token) do
    case Jason.encode(token) do
      {:ok, json} ->
        _ =
          Secrets.upsert_named(
            Repo,
            connection.tenant_id,
            secret_name_from_connection(connection),
            json
          )

        :ok

      {:error, _} ->
        :ok
    end
  end

  defp fetch_token(%ChannelConnection{} = connection) do
    case Secrets.get_secret_value(connection) do
      nil ->
        {:error, :missing_whatsapp_token}

      value ->
        case Jason.decode(value) do
          {:ok, token} -> {:ok, token}
          {:error, _} -> {:error, :invalid_whatsapp_token}
        end
    end
  end

  defp build_send_payload(attrs) do
    to = Map.get(attrs, "to") || Map.get(attrs, :to)
    text = Map.get(attrs, "text") || Map.get(attrs, :text)

    normalized = normalize_phone_number(to)
    to_value = if is_binary(normalized), do: String.replace(normalized, "+", ""), else: nil

    if is_nil(to_value) or is_nil(text) or text == "" do
      {:error, :message_payload_invalid}
    else
      {:ok,
       %{
         "messaging_product" => "whatsapp",
         "to" => to_value,
         "type" => "text",
         "text" => %{"body" => text}
       }}
    end
  end

  defp phone_number_id_from_connection(%ChannelConnection{} = connection) do
    value =
      connection.metadata
      |> Kernel.||(%{})
      |> Map.get("phone_number_id")

    if is_binary(value) do
      {:ok, value}
    else
      {:error, :missing_phone_number_id}
    end
  end

  defp waba_id_from_connection(%ChannelConnection{} = connection) do
    value =
      connection.metadata
      |> Kernel.||(%{})
      |> Map.get("waba_id")

    if is_binary(value) do
      {:ok, value}
    else
      {:error, :missing_waba_id}
    end
  end

  def normalize_phone_number(nil), do: nil

  def normalize_phone_number(phone_number) do
    digits =
      phone_number
      |> to_string()
      |> String.replace(~r/\D+/, "")

    case digits do
      "" -> nil
      value -> "+" <> value
    end
  end

  defp normalize_token(token) when is_map(token) do
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

    if is_integer(expires_in) do
      expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second) |> DateTime.to_iso8601()
      Map.put(token, "expires_at", expires_at)
    else
      token
    end
  end

  defp normalize_token(token), do: token

  defp token_expired?(expires_at) do
    case parse_datetime(expires_at) do
      {:ok, dt} -> DateTime.compare(dt, DateTime.utc_now()) == :lt
      _ -> true
    end
  end

  defp parse_datetime(nil), do: {:error, :invalid}

  defp parse_datetime(value) when is_binary(value) do
    DateTime.from_iso8601(value)
  end

  defp parse_datetime(%DateTime{} = dt), do: {:ok, dt}
  defp parse_datetime(_), do: {:error, :invalid}

  defp value_from_config(config, key) do
    case config do
      map when is_map(map) -> Map.get(map, key) || Map.get(map, to_string(key))
      list when is_list(list) -> Keyword.get(list, key)
      _ -> nil
    end
  end

  defp secret_name(waba_id), do: "channel:whatsapp:waba:#{waba_id}"

  defp secret_name_from_connection(%ChannelConnection{} = connection) do
    case waba_id_from_connection(connection) do
      {:ok, waba_id} -> secret_name(waba_id)
      _ -> "channel:whatsapp:connection:#{connection.id}"
    end
  end
end
