defmodule Swati.Inbound do
  alias Swati.Channels
  alias Swati.Inbound.Commands
  alias Swati.Inbound.Connector
  alias Swati.Inbound.Delivery
  alias Swati.Inbound.Parser.Resend, as: ResendParser
  alias Swati.Inbound.Processor
  alias Swati.Inbound.Queries
  alias Swati.Inbound.Routing
  alias Swati.Inbound.Secrets
  alias Swati.Inbound.Signatures.Resend, as: ResendSignature
  alias Swati.Workers.ProcessInboundDelivery
  alias Oban

  @inbound_feature_flag :inbound_connectors_v1

  def enabled? do
    Application.get_env(:swati, @inbound_feature_flag, true)
  end

  def list_connectors(tenant_id), do: Queries.list_connectors(tenant_id)
  def get_connector!(tenant_id, connector_id), do: Queries.get_connector!(tenant_id, connector_id)
  def list_rules(tenant_id), do: Queries.list_rules(tenant_id)
  def list_deliveries(tenant_id, opts \\ []), do: Queries.list_deliveries(tenant_id, opts)
  def get_delivery!(tenant_id, delivery_id), do: Queries.get_delivery!(tenant_id, delivery_id)
  def list_address_bindings(tenant_id), do: Queries.list_email_bindings(tenant_id)
  def list_email_messages(tenant_id, opts \\ []), do: Queries.list_email_messages(tenant_id, opts)

  def list_thread_ownership_events_for_session(tenant_id, session_id, opts \\ []),
    do: Queries.list_thread_ownership_events_for_session(tenant_id, session_id, opts)

  def list_deliveries_for_session(tenant_id, session_id) do
    Queries.list_deliveries_for_session(tenant_id, session_id)
  end

  def list_email_sessions(tenant_id, opts \\ []), do: Queries.list_email_sessions(tenant_id, opts)

  def get_email_session(tenant_id, session_id),
    do: Queries.get_email_session(tenant_id, session_id)

  def create_connector(tenant_id, attrs), do: Commands.create_connector(tenant_id, attrs)

  def update_connector(%Connector{} = connector, attrs),
    do: Commands.update_connector(connector, attrs)

  def delete_connector(%Connector{} = connector), do: Commands.delete_connector(connector)

  def create_rule(tenant_id, attrs), do: Commands.create_rule(tenant_id, attrs)

  def update_rule(%Swati.Inbound.AgentRule{} = rule, attrs), do: Commands.update_rule(rule, attrs)

  def delete_rule(%Swati.Inbound.AgentRule{} = rule), do: Commands.delete_rule(rule)

  def get_rule!(tenant_id, rule_id), do: Queries.get_rule!(tenant_id, rule_id)

  def upsert_address_binding(tenant_id, address, owner_agent_id) do
    attrs =
      if is_binary(owner_agent_id) and owner_agent_id != "" do
        %{routing_policy: %{"default_agent_id" => owner_agent_id}}
      else
        %{routing_policy: %{}}
      end

    Channels.ensure_endpoint_for_email(tenant_id, address, attrs)
  end

  def clear_address_binding(endpoint), do: Channels.update_endpoint_routing(endpoint, %{})

  def replay_delivery(%Delivery{} = delivery) do
    if delivery.status in [:received, :processing] do
      {:error, :delivery_busy}
    else
      with {:ok, replayable} <-
             Commands.update_delivery(delivery, %{
               status: :received,
               processing_error: nil,
               processed_at: nil
             }),
           {:ok, _job} <- enqueue_processing(replayable.id) do
        :telemetry.execute(
          [:swati, :inbound, :delivery, :replay],
          %{count: 1},
          %{status: to_string(replayable.status), provider: replayable.provider}
        )

        {:ok, replayable}
      end
    end
  end

  def preview_route(%Connector{} = connector, attrs) when is_map(attrs) do
    envelope = %{
      "provider" => "resend",
      "from" => Map.get(attrs, "from"),
      "to" => parse_email_list(Map.get(attrs, "to")),
      "subject" => Map.get(attrs, "subject"),
      "message_id" => Map.get(attrs, "message_id"),
      "in_reply_to" => Map.get(attrs, "in_reply_to"),
      "references" => parse_list(Map.get(attrs, "references"))
    }

    case Routing.resolve_route(connector, envelope) do
      {:ok, route} -> {:ok, %{route: route, envelope: envelope}}
      {:error, reason} -> {:error, reason}
    end
  end

  def webhook_url(%Connector{} = connector) do
    webhook_base_url()
    |> String.trim_trailing("/")
    |> Kernel.<>("/api/v1/inbound/")
    |> Kernel.<>(connector.endpoint_token)
  end

  def ingest_webhook(connector_token, headers, raw_body, payload)
      when is_binary(connector_token) do
    started_at = System.monotonic_time()

    result =
      if enabled?() do
        with %Connector{} = connector <- Queries.get_connector_by_token(connector_token),
             true <- connector.status == :active or {:error, :connector_disabled},
             :ok <- verify_signature(connector, headers, raw_body),
             envelope <- ResendParser.normalize(payload || %{}),
             attrs <- delivery_attrs(connector, headers, payload, envelope, true, nil),
             {:ok, delivery} <- Commands.create_delivery(attrs) do
          if is_nil(delivery.id) do
            {:ok, %{duplicate?: true}}
          else
            enqueue_processing(delivery.id)
            {:ok, %{delivery_id: delivery.id, duplicate?: false}}
          end
        else
          nil ->
            {:error, :connector_not_found}

          {:error, reason} ->
            maybe_store_failed_delivery(connector_token, headers, payload, raw_body, reason)
            {:error, reason}

          {:ok, %Swati.Inbound.Delivery{id: nil}} ->
            {:ok, %{duplicate?: true}}

          {:ok, %Swati.Inbound.Delivery{} = delivery} ->
            enqueue_processing(delivery.id)
            {:ok, %{delivery_id: delivery.id, duplicate?: false}}
        end
      else
        {:error, :feature_disabled}
      end

    duration_ms =
      (System.monotonic_time() - started_at) |> System.convert_time_unit(:native, :millisecond)

    :telemetry.execute(
      [:swati, :inbound, :webhook, :ingest],
      %{count: 1, duration_ms: duration_ms},
      %{
        status: ingest_status(result)
      }
    )

    result
  end

  def process_delivery(delivery_id), do: Processor.process_delivery(delivery_id)

  defp verify_signature(%Connector{provider: :resend} = connector, headers, raw_body) do
    signing_secret = Secrets.get_secret_value(connector.signing_secret_id)

    ResendSignature.verify(headers, raw_body || "", signing_secret)
  end

  defp verify_signature(_connector, _headers, _raw_body), do: {:error, :unsupported_provider}

  defp enqueue_processing(delivery_id) do
    %{"delivery_id" => delivery_id}
    |> ProcessInboundDelivery.new(queue: :channels, unique: [fields: [:args]])
    |> Oban.insert()
  end

  defp delivery_attrs(connector, headers, payload, envelope, signature_valid, signature_error) do
    provider_event_id = envelope["provider_event_id"]

    idempotency_key =
      provider_event_id ||
        (payload || %{})
        |> Jason.encode!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

    %{
      tenant_id: connector.tenant_id,
      connector_id: connector.id,
      provider: provider(connector),
      provider_event_id: provider_event_id,
      idempotency_key: idempotency_key,
      event_type: envelope["event_type"],
      status: :received,
      signature_valid: signature_valid,
      signature_error: if(signature_error, do: inspect(signature_error), else: nil),
      request_headers: headers,
      payload: payload,
      received_at: DateTime.utc_now()
    }
  end

  defp maybe_store_failed_delivery(connector_token, headers, payload, _raw_body, reason) do
    case Queries.get_connector_by_token(connector_token) do
      %Connector{} = connector ->
        envelope = ResendParser.normalize(payload || %{})

        attrs =
          delivery_attrs(connector, headers, payload, envelope, false, reason)
          |> Map.put(:status, :failed)
          |> Map.put(:processing_error, inspect(reason))
          |> Map.put(:processed_at, DateTime.utc_now())

        _ = Commands.create_delivery(attrs)
        :ok

      _ ->
        :ok
    end
  end

  defp provider(%Connector{provider: provider}) when is_atom(provider),
    do: Atom.to_string(provider)

  defp provider(%Connector{provider: provider}), do: to_string(provider)

  defp ingest_status({:ok, %{duplicate?: true}}), do: "duplicate"
  defp ingest_status({:ok, _}), do: "accepted"
  defp ingest_status({:error, reason}), do: to_string(reason)
  defp ingest_status(_), do: "unknown"

  defp parse_email_list(nil), do: []

  defp parse_email_list(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&normalize_email/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_email_list(value) when is_list(value) do
    value
    |> Enum.map(&normalize_email/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_email_list(_value), do: []

  defp parse_list(nil), do: []

  defp parse_list(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_list(value) when is_list(value) do
    value
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_list(value), do: [to_string(value)]

  defp normalize_email(value) when is_binary(value) do
    value
    |> String.trim()
    |> extract_bracket_email()
    |> String.downcase()
  end

  defp normalize_email(value), do: value |> to_string() |> normalize_email()

  defp extract_bracket_email(value) do
    case Regex.run(~r/<\s*([^>]+)\s*>/, value, capture: :all_but_first) do
      [email] -> String.trim(email)
      _ -> value
    end
  end

  defp webhook_base_url do
    Application.get_env(:swati, :inbound_webhook_base_url) ||
      ngrok_base_url() ||
      whatsapp_base_url() ||
      SwatiWeb.Endpoint.url()
  end

  defp ngrok_base_url do
    case Req.get("http://127.0.0.1:4040/api/tunnels", receive_timeout: 400, retry: false) do
      {:ok, %Req.Response{status: 200, body: %{"tunnels" => tunnels}}} when is_list(tunnels) ->
        tunnels
        |> Enum.find_value(fn tunnel ->
          case tunnel do
            %{"public_url" => "https://" <> _ = url} -> url
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp whatsapp_base_url do
    config = Application.get_env(:swati, :whatsapp, %{})

    callback =
      if is_list(config) do
        Keyword.get(config, :webhook_callback_url)
      else
        Map.get(config, :webhook_callback_url) || Map.get(config, "webhook_callback_url")
      end

    if is_binary(callback) do
      case URI.parse(callback) do
        %URI{scheme: scheme, host: host} = uri when is_binary(scheme) and is_binary(host) ->
          port =
            cond do
              not is_integer(uri.port) -> ""
              uri.port == 80 and scheme == "http" -> ""
              uri.port == 443 and scheme == "https" -> ""
              true -> ":#{uri.port}"
            end

          "#{scheme}://#{host}#{port}"

        _ ->
          nil
      end
    else
      nil
    end
  end
end
