defmodule SwatiWeb.Internal.CallsController do
  use SwatiWeb, :controller

  alias Swati.Calls
  alias Swati.Telephony

  def start(conn, params) do
    phone_number_id = Map.get(params, "phone_number_id") || Map.get(params, :phone_number_id)
    phone_number = Telephony.get_phone_number!(phone_number_id)

    case phone_number.inbound_agent_id do
      nil ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "phone_number_missing_agent"})

      agent_id ->
        started_at = parse_datetime(Map.get(params, "started_at") || Map.get(params, :started_at))

        attrs = %{
          tenant_id: phone_number.tenant_id,
          agent_id: agent_id,
          phone_number_id: phone_number.id,
          provider: Map.get(params, "provider") || Map.get(params, :provider),
          provider_call_id:
            Map.get(params, "provider_call_id") || Map.get(params, :provider_call_id),
          provider_stream_id:
            Map.get(params, "provider_stream_id") || Map.get(params, :provider_stream_id),
          from_number: Map.get(params, "from_number") || Map.get(params, :from_number),
          to_number: Map.get(params, "to_number") || Map.get(params, :to_number),
          status: :started,
          started_at: started_at
        }

        case Calls.create_call_start(attrs) do
          {:ok, call} ->
            json(conn, %{call_id: call.id})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> render_changeset(changeset)
        end
    end
  end

  def events(conn, %{"call_id" => call_id, "events" => events}) when is_list(events) do
    parsed_events =
      Enum.map(events, fn event ->
        %{
          "ts" => parse_datetime(Map.get(event, "ts") || Map.get(event, :ts)),
          "type" => Map.get(event, "type") || Map.get(event, :type),
          "payload" => Map.get(event, "payload") || Map.get(event, :payload)
        }
      end)

    _ = Calls.append_call_events(call_id, parsed_events)
    json(conn, %{status: "ok"})
  end

  def end_call(conn, %{"call_id" => call_id} = params) do
    ended_at = parse_datetime(Map.get(params, "ended_at") || Map.get(params, :ended_at))
    duration = Map.get(params, "duration_seconds") || Map.get(params, :duration_seconds)
    status = Map.get(params, "status") || Map.get(params, :status)

    case Calls.set_call_end(call_id, ended_at, duration, status) do
      {:ok, call} ->
        json(conn, %{call_id: call.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  def artifacts(conn, %{"call_id" => call_id} = params) do
    recording = Map.get(params, "recording") || Map.get(params, :recording)
    transcript = Map.get(params, "transcript") || Map.get(params, :transcript)

    case Calls.set_call_artifacts(call_id, recording, transcript) do
      {:ok, call} ->
        json(conn, %{call_id: call.id})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_changeset(changeset)
    end
  end

  defp parse_datetime(%DateTime{} = dt), do: DateTime.truncate(dt, :microsecond)

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :microsecond)
      _ -> DateTime.utc_now()
    end
  end

  defp parse_datetime(_), do: DateTime.utc_now()

  defp render_changeset(conn, %Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
        SwatiWeb.CoreComponents.translate_error({message, opts})
      end)

    json(conn, %{error: errors})
  end
end
