defmodule Swati.Calls.Ingestion do
  alias Swati.Calls
  alias Swati.Calls.CallStatusTransitions
  alias Swati.Calls.Events
  alias Swati.Telephony

  @spec start(map()) ::
          {:ok, %Swati.Calls.Call{}}
          | {:error, :phone_number_missing_agent | Ecto.Changeset.t()}
  def start(params) do
    phone_number_id = Map.get(params, "phone_number_id") || Map.get(params, :phone_number_id)
    phone_number = Telephony.get_phone_number!(phone_number_id)

    case phone_number.inbound_agent_id do
      nil ->
        {:error, :phone_number_missing_agent}

      agent_id ->
        started_at =
          Events.parse_datetime(Map.get(params, "started_at") || Map.get(params, :started_at))

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

        Calls.create_call_start(attrs)
    end
  end

  @spec append_events(binary(), list(map())) :: :ok
  def append_events(call_id, events) when is_list(events) do
    parsed_events = Enum.map(events, &Events.normalize/1)
    _ = Calls.append_call_events(call_id, parsed_events)
    :ok
  end

  @spec end_call(binary(), map()) ::
          {:ok, %Swati.Calls.Call{}} | {:error, Ecto.Changeset.t()}
  def end_call(call_id, params) when is_map(params) do
    ended_at = Events.parse_datetime(Map.get(params, "ended_at") || Map.get(params, :ended_at))
    duration = Map.get(params, "duration_seconds") || Map.get(params, :duration_seconds)

    status =
      CallStatusTransitions.normalize_end_status(
        Map.get(params, "status") || Map.get(params, :status)
      )

    Calls.set_call_end(call_id, ended_at, duration, status)
  end

  @spec set_artifacts(binary(), map()) ::
          {:ok, %Swati.Calls.Call{}} | {:error, Ecto.Changeset.t()}
  def set_artifacts(call_id, params) when is_map(params) do
    recording = Map.get(params, "recording") || Map.get(params, :recording)
    transcript = Map.get(params, "transcript") || Map.get(params, :transcript)

    Calls.set_call_artifacts(call_id, recording, transcript)
  end
end
