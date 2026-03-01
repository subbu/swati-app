defmodule Swati.Inbound.Processor do
  alias Swati.Channels.Ingestion
  alias Swati.Inbound.Commands
  alias Swati.Inbound.Delivery
  alias Swati.Inbound.Ownership
  alias Swati.Inbound.Parser.Resend, as: ResendParser
  alias Swati.Inbound.Queries
  alias Swati.Inbound.ResendClient
  alias Swati.Inbound.Routing
  alias Swati.Repo
  alias Swati.Sessions

  def process_delivery(delivery_id) when is_binary(delivery_id) do
    started_at = System.monotonic_time()

    result =
      with %Delivery{} = delivery <- Queries.get_delivery(delivery_id),
           :ok <- ensure_processable(delivery),
           {:ok, delivery} <- Commands.update_delivery(delivery, %{status: :processing}),
           {:ok, envelope, envelope_meta} <- normalize_envelope(delivery),
           {:ok, route} <- Routing.resolve_route(delivery.connector, envelope),
           {:ok, params, route_details} <- build_ingest_params(delivery, envelope, route),
           {:ok, runtime_result} <- Ingestion.ingest_events(params),
           :ok <- maybe_persist_session_routing(runtime_result, route, envelope, delivery.id),
           {:ok, _delivery} <-
             Commands.update_delivery(delivery, %{
               status: :processed,
               normalized_payload: envelope,
               route_details: Map.merge(route_details, envelope_meta),
               runtime_result: runtime_result,
               processing_error: nil,
               processed_at: DateTime.utc_now()
             }) do
        :ok
      else
        nil ->
          {:error, :delivery_not_found}

        {:skip, _reason} ->
          :ok

        {:error, reason} ->
          mark_failed(delivery_id, reason)
          {:error, reason}
      end

    duration_ms =
      System.monotonic_time()
      |> Kernel.-(started_at)
      |> System.convert_time_unit(:native, :millisecond)

    :telemetry.execute(
      [:swati, :inbound, :delivery, :process],
      %{count: 1, duration_ms: duration_ms},
      %{status: process_status(result)}
    )

    result
  end

  defp ensure_processable(%Delivery{status: status})
       when status in [:processed, :duplicate, :ignored] do
    {:skip, :already_processed}
  end

  defp ensure_processable(_delivery), do: :ok

  defp normalize_envelope(%Delivery{provider: "resend", payload: payload}) do
    base = ResendParser.normalize(payload || %{})
    email_id = base["provider_event_id"]

    case ResendClient.fetch_email(email_id) do
      {:ok, fetched} ->
        {:ok, ResendParser.normalize(payload || %{}, fetched), %{fetch_source: "resend_api"}}

      {:error, reason} ->
        {:ok, base, %{fetch_source: "webhook_only", fetch_error: inspect(reason)}}
    end
  end

  defp normalize_envelope(%Delivery{} = delivery) do
    {:error, {:unsupported_provider, delivery.provider}}
  end

  defp build_ingest_params(delivery, envelope, route) do
    from = Map.get(envelope, "from")

    if is_binary(from) and String.trim(from) != "" do
      text_body =
        Map.get(envelope, "text_body") ||
          html_to_text(Map.get(envelope, "html_body")) ||
          subject_fallback(Map.get(envelope, "subject"))

      payload = %{
        "provider" => Map.get(envelope, "provider"),
        "provider_event_id" => Map.get(envelope, "provider_event_id"),
        "message_id" => Map.get(envelope, "message_id"),
        "in_reply_to" => Map.get(envelope, "in_reply_to"),
        "references" => Map.get(envelope, "references") || [],
        "from" => from,
        "to" => Map.get(envelope, "to") || [],
        "cc" => Map.get(envelope, "cc") || [],
        "bcc" => Map.get(envelope, "bcc") || [],
        "subject" => Map.get(envelope, "subject"),
        "text" => text_body,
        "html" => Map.get(envelope, "html_body"),
        "attachments" => Map.get(envelope, "attachments") || []
      }

      params = %{
        "channel_key" => route.endpoint.channel.key,
        "endpoint_address" => route.endpoint.address,
        "from_address" => from,
        "customer_kind" => "email",
        "customer_address" => from,
        "session_external_id" => route.thread_key,
        "direction" => "inbound",
        "provider" => "resend",
        "subject" => Map.get(envelope, "subject"),
        "event" => %{
          "type" => "channel.message.received",
          "source" => "channel",
          "payload" => payload
        },
        "agent_id" => route.owner_agent_id,
        "case_id" => route.continuity[:case_id]
      }

      route_details = %{
        "connector_id" => delivery.connector_id,
        "route_reason" => route.route_reason,
        "thread_key" => route.thread_key,
        "endpoint_id" => route.endpoint.id,
        "endpoint_address" => route.endpoint.address,
        "owner_agent_id" => route.owner_agent_id,
        "watcher_agent_ids" => route.watcher_agent_ids || [],
        "matched_rule_ids" => route.matched_rule_ids || [],
        "owner_candidates" => route.owner_candidates || [],
        "continuity" => route.continuity
      }

      {:ok, params, route_details}
    else
      {:error, :from_address_missing}
    end
  end

  defp html_to_text(nil), do: nil

  defp html_to_text(html) when is_binary(html) do
    html
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp html_to_text(_value), do: nil

  defp subject_fallback(subject) when is_binary(subject) do
    trimmed = String.trim(subject)
    if trimmed == "", do: "(no body)", else: "Subject: #{trimmed}"
  end

  defp subject_fallback(_subject), do: "(no body)"

  defp maybe_persist_session_routing(runtime_result, route, envelope, delivery_id) do
    session_id = Map.get(runtime_result, "session_id") || Map.get(runtime_result, :session_id)

    if is_binary(session_id) do
      case Repo.get(Swati.Sessions.Session, session_id) do
        %Swati.Sessions.Session{} = session ->
          inbound_routing = %{
            "delivery_id" => delivery_id,
            "route_reason" => route.route_reason,
            "thread_key" => route.thread_key,
            "owner_agent_id" => route.owner_agent_id,
            "watcher_agent_ids" => route.watcher_agent_ids || [],
            "matched_rule_ids" => route.matched_rule_ids || [],
            "owner_candidates" => route.owner_candidates || [],
            "continuity" => route.continuity,
            "subject" => Map.get(envelope, "subject"),
            "from" => Map.get(envelope, "from"),
            "to" => Map.get(envelope, "to") || [],
            "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
          }

          metadata = (session.metadata || %{}) |> Map.put("inbound_routing", inbound_routing)

          _ = Sessions.update_session(session, %{metadata: metadata})

          _ =
            Ownership.record_route(session, route, %{
              delivery_id: delivery_id,
              metadata: %{
                "matched_rule_ids" => route.matched_rule_ids || [],
                "watcher_agent_ids" => route.watcher_agent_ids || []
              }
            })

          Sessions.append_events(session.id, [
            %{
              ts: DateTime.utc_now(),
              type: "inbound.routing.resolved",
              source: "inbound",
              payload: inbound_routing
            }
          ])

          :ok

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp process_status(:ok), do: "ok"
  defp process_status({:error, reason}), do: inspect(reason)
  defp process_status(_), do: "unknown"

  defp mark_failed(delivery_id, reason) do
    case Queries.get_delivery(delivery_id) do
      %Delivery{} = delivery ->
        _ =
          Commands.update_delivery(delivery, %{
            status: :failed,
            processing_error: inspect(reason),
            processed_at: DateTime.utc_now()
          })

        :ok

      _ ->
        :ok
    end
  end
end
