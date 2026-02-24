defmodule Swati.Channels.WhatsApp.TemplateMessages do
  import Ecto.Query, warn: false

  alias Swati.Channels.ChannelConnection
  alias Swati.Channels.WhatsApp.TemplateMessage
  alias Swati.Repo
  alias Swati.Tenancy

  @event_list_key "events"

  def list_recent(tenant_id, connection_id, opts \\ []) do
    limit = normalize_limit(opts)

    TemplateMessage
    |> Tenancy.scope(tenant_id)
    |> where([m], m.connection_id == ^connection_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def get_by_meta_message_id(tenant_id, meta_message_id)
      when is_binary(meta_message_id) do
    TemplateMessage
    |> Tenancy.scope(tenant_id)
    |> where([m], m.meta_message_id == ^meta_message_id)
    |> Repo.one()
  end

  def record_send(%ChannelConnection{} = connection, attrs, payload, provider_response)
      when is_map(attrs) and is_map(payload) and is_map(provider_response) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    meta_message_id = extract_message_id(provider_response)
    recipient = Map.get(attrs, "to") || Map.get(attrs, :to)

    params = %{
      tenant_id: connection.tenant_id,
      connection_id: connection.id,
      waba_id: connection_metadata(connection, "waba_id"),
      phone_number_id: connection_metadata(connection, "phone_number_id"),
      recipient: to_string(recipient || ""),
      template_name: get_in(payload, ["template", "name"]) || "unknown_template",
      template_language: get_in(payload, ["template", "language", "code"]) || "en_US",
      meta_message_id: meta_message_id,
      status: "sent",
      sent_at: now,
      status_events: %{
        @event_list_key => [
          %{
            "status" => "sent",
            "at" => DateTime.to_iso8601(now),
            "raw" => provider_response
          }
        ]
      },
      provider_response: provider_response,
      template_payload: payload
    }

    upsert_on_message_id(meta_message_id, params)
  end

  def apply_delivery_status(%ChannelConnection{} = connection, payload) when is_map(payload) do
    meta_message_id = Map.get(payload, "id")

    if is_binary(meta_message_id) do
      status = normalize_status(Map.get(payload, "status"))
      status_at = status_datetime(payload)
      event = build_event(status, status_at, payload)

      case get_by_meta_message_id(connection.tenant_id, meta_message_id) do
        nil ->
          insert_from_webhook(connection, meta_message_id, status, status_at, event, payload)

        %TemplateMessage{} = message ->
          update_from_webhook(message, status, status_at, event, payload)
      end
    else
      {:error, :meta_message_id_missing}
    end
  end

  def normalize_status(nil), do: "unknown"

  def normalize_status(status) do
    status
    |> to_string()
    |> String.downcase()
    |> case do
      "queued" -> "queued"
      "accepted" -> "sent"
      "sent" -> "sent"
      "delivered" -> "delivered"
      "read" -> "read"
      "failed" -> "failed"
      "warning" -> "warning"
      _ -> "unknown"
    end
  end

  defp insert_from_webhook(connection, meta_message_id, status, status_at, event, payload) do
    params =
      %{
        tenant_id: connection.tenant_id,
        connection_id: connection.id,
        waba_id: connection_metadata(connection, "waba_id"),
        phone_number_id: connection_metadata(connection, "phone_number_id"),
        recipient: Map.get(payload, "recipient_id") || "unknown",
        template_name: "unknown_template",
        template_language: "en_US",
        meta_message_id: meta_message_id,
        status: status,
        status_events: %{@event_list_key => [event]}
      }
      |> merge_status_timestamps(status, status_at)

    %TemplateMessage{}
    |> TemplateMessage.changeset(params)
    |> Repo.insert()
  end

  defp update_from_webhook(%TemplateMessage{} = message, status, status_at, event, payload) do
    events =
      message.status_events
      |> events_list()
      |> Kernel.++([event])

    attrs =
      %{
        status: status,
        status_events: %{@event_list_key => events},
        provider_response:
          Map.merge(message.provider_response || %{}, %{
            "latest_status" => payload
          })
      }
      |> merge_status_timestamps(status, status_at)

    message
    |> TemplateMessage.changeset(attrs)
    |> Repo.update()
  end

  defp upsert_on_message_id(nil, params) do
    %TemplateMessage{}
    |> TemplateMessage.changeset(params)
    |> Repo.insert()
  end

  defp upsert_on_message_id(meta_message_id, params) do
    case get_by_meta_message_id(params.tenant_id, meta_message_id) do
      nil ->
        %TemplateMessage{}
        |> TemplateMessage.changeset(params)
        |> Repo.insert()

      %TemplateMessage{} = message ->
        message
        |> TemplateMessage.changeset(params)
        |> Repo.update()
    end
  end

  defp merge_status_timestamps(attrs, status, %DateTime{} = status_at) do
    status_iso = DateTime.to_iso8601(status_at)

    attrs
    |> Map.put_new(:sent_at, status_at)
    |> maybe_put_timestamp(:delivered_at, status == "delivered", status_at)
    |> maybe_put_timestamp(:read_at, status == "read", status_at)
    |> maybe_put_timestamp(:failed_at, status == "failed", status_at)
    |> Map.update(:status_events, %{@event_list_key => []}, fn map ->
      Map.update(map, "last_seen_at", status_iso, fn _ -> status_iso end)
    end)
  end

  defp merge_status_timestamps(attrs, _status, _), do: attrs

  defp maybe_put_timestamp(attrs, key, true, value), do: Map.put_new(attrs, key, value)
  defp maybe_put_timestamp(attrs, _key, false, _value), do: attrs

  defp status_datetime(payload) do
    case Map.get(payload, "timestamp") do
      value when is_integer(value) -> DateTime.from_unix!(value)
      value when is_binary(value) -> parse_timestamp(value)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp parse_timestamp(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, _} -> DateTime.from_unix!(seconds)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end

  defp build_event(status, status_at, payload) do
    %{
      "status" => status,
      "at" => DateTime.to_iso8601(status_at),
      "recipient_id" => Map.get(payload, "recipient_id"),
      "raw" => payload
    }
  end

  defp events_list(%{@event_list_key => events}) when is_list(events), do: events
  defp events_list(_), do: []

  defp extract_message_id(response) do
    get_in(response, ["messages", Access.at(0), "id"])
  end

  defp connection_metadata(connection, key) do
    connection
    |> Map.get(:metadata, %{})
    |> Map.get(key)
  end

  defp normalize_limit(opts) do
    opts
    |> Keyword.get(:limit, 20)
    |> max(1)
    |> min(100)
  end
end
