defmodule Swati.Channels.WhatsApp.WebhookProcessor do
  alias Swati.Channels
  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.Ingestion
  alias Swati.Channels.Queries
  alias Swati.Channels.WhatsApp
  alias Swati.Repo

  def handle_webhook(%{"entry" => entries}) when is_list(entries) do
    Enum.each(entries, &process_entry/1)
    :ok
  end

  def handle_webhook(_params), do: :ok

  defp process_entry(%{"changes" => changes}) when is_list(changes) do
    Enum.each(changes, fn change ->
      case Map.get(change, "field") do
        "messages" -> process_messages(Map.get(change, "value", %{}))
        "message_template_status_update" -> process_template_update(Map.get(change, "value", %{}))
        "account_update" -> process_account_update(Map.get(change, "value", %{}))
        _ -> :ok
      end
    end)
  end

  defp process_entry(_entry), do: :ok

  defp process_messages(%{"messages" => messages} = payload) when is_list(messages) do
    if messages == [] do
      :ok
    else
      metadata = Map.get(payload, "metadata") || %{}
      phone_number_id = Map.get(metadata, "phone_number_id")
      display_phone_number = Map.get(metadata, "display_phone_number")
      contact_name = contact_name(payload)

      with {:ok, connection} <- lookup_connection(phone_number_id, display_phone_number) do
        endpoint_address = connection.endpoint.address
        events = Enum.map(messages, &build_event(&1, endpoint_address))
        first = List.first(messages)

        params = %{
          "channel_key" => "whatsapp",
          "channel_type" => "whatsapp",
          "endpoint_address" => endpoint_address,
          "from_address" => Map.get(first, "from"),
          "customer_address" => Map.get(first, "from"),
          "customer_name" => contact_name,
          "direction" => "inbound",
          "session_external_id" => Map.get(first, "from"),
          "started_at" => message_timestamp(first),
          "provider" => "whatsapp"
        }

        _ = Ingestion.ingest_events(Map.put(params, "events", events))

        :ok
      end
    end
  end

  defp process_messages(_payload), do: :ok

  defp build_event(message, endpoint_address) do
    %{
      "ts" => message_timestamp(message),
      "type" => "channel.message.received",
      "source" => "channel",
      "idempotency_key" => "whatsapp:#{Map.get(message, "id")}",
      "payload" => message_payload(message, endpoint_address)
    }
  end

  defp message_payload(message, endpoint_address) do
    %{
      "provider" => "whatsapp",
      "message_id" => Map.get(message, "id"),
      "from" => Map.get(message, "from"),
      "to" => endpoint_address,
      "type" => Map.get(message, "type"),
      "text" => get_in(message, ["text", "body"]),
      "raw" => message
    }
  end

  defp process_template_update(payload) when is_map(payload) do
    waba_id = Map.get(payload, "waba_id")

    if is_binary(waba_id) do
      connections = Queries.list_whatsapp_connections_by_waba_id(waba_id)

      update_connections_status(connections, nil, %{
        "template_status" => Map.get(payload, "event") || Map.get(payload, "status"),
        "template_name" => Map.get(payload, "template_name")
      })
    end

    :ok
  end

  defp process_account_update(payload) when is_map(payload) do
    phone_number_id = Map.get(payload, "phone_number_id")
    waba_id = Map.get(payload, "waba_id")

    connections =
      cond do
        is_binary(phone_number_id) ->
          case Queries.get_whatsapp_connection_by_phone_number_id(phone_number_id) do
            nil -> []
            connection -> [connection]
          end

        is_binary(waba_id) ->
          Queries.list_whatsapp_connections_by_waba_id(waba_id)

        true ->
          []
      end

    update_connections_status(connections, nil, %{
      "quality_rating" => Map.get(payload, "quality_rating"),
      "messaging_limit" => Map.get(payload, "messaging_limit"),
      "account_status" => Map.get(payload, "account_status")
    })

    :ok
  end

  defp update_connections_status(connections, nil, metadata) do
    Enum.each(connections, &update_connection_metadata(&1, metadata))
  end

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

  defp contact_name(payload) do
    payload
    |> Map.get("contacts")
    |> List.wrap()
    |> List.first()
    |> get_in(["profile", "name"])
  end

  defp message_timestamp(message) do
    case Map.get(message, "timestamp") do
      nil ->
        DateTime.utc_now()

      value ->
        value
        |> to_string()
        |> Integer.parse()
        |> case do
          {seconds, _} -> DateTime.from_unix!(seconds)
          _ -> DateTime.utc_now()
        end
    end
  end

  defp lookup_connection(phone_number_id, display_phone_number) do
    cond do
      is_binary(phone_number_id) ->
        case Queries.get_whatsapp_connection_by_phone_number_id(phone_number_id) do
          nil -> {:error, :connection_not_found}
          connection -> {:ok, Repo.preload(connection, :endpoint)}
        end

      is_binary(display_phone_number) ->
        address = WhatsApp.normalize_phone_number(display_phone_number)

        case Channels.get_endpoint_by_channel_key_any_status("whatsapp", address) do
          nil ->
            {:error, :connection_not_found}

          endpoint ->
            connection = Channels.get_connection_by_endpoint(endpoint.tenant_id, endpoint.id)

            if connection do
              {:ok, Repo.preload(connection, :endpoint)}
            else
              {:error, :connection_not_found}
            end
        end

      true ->
        {:error, :connection_not_found}
    end
  end
end
