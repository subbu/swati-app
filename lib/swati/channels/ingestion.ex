defmodule Swati.Channels.Ingestion do
  alias Swati.Runtime
  alias Swati.Sessions

  @spec ingest_events(map()) :: {:ok, map()} | {:error, term()}
  def ingest_events(params) when is_map(params) do
    with {:ok, runtime} <- Runtime.resolve_runtime(params) do
      session_id = runtime.session.id
      events = normalize_events(params)
      :ok = Sessions.append_events(session_id, events)

      {:ok,
       %{
         runtime: runtime,
         session_id: session_id,
         case_id: runtime.case.id,
         customer_id: runtime.customer.id
       }}
    end
  end

  @spec request_send(map()) :: {:ok, map()} | {:error, term()}
  def request_send(params) when is_map(params) do
    session_id = Map.get(params, "session_id") || Map.get(params, :session_id)

    if is_nil(session_id) do
      {:error, :session_id_required}
    else
      payload =
        Map.get(params, "payload") || Map.get(params, :payload) ||
          Map.get(params, "message") || Map.get(params, :message) || %{}

      payload =
        if payload == %{} do
          text = Map.get(params, "text") || Map.get(params, :text)
          if is_nil(text), do: %{}, else: %{"text" => text}
        else
          payload
        end

      event = %{
        ts: Map.get(params, "ts") || Map.get(params, :ts) || DateTime.utc_now(),
        type: Map.get(params, "type") || Map.get(params, :type) || "channel.message.sent",
        source: Map.get(params, "source") || Map.get(params, :source) || "channel",
        payload: payload
      }

      :ok = Sessions.append_events(session_id, [event])

      {:ok, %{session_id: session_id}}
    end
  end

  defp normalize_events(params) do
    events =
      case Map.get(params, "events") || Map.get(params, :events) do
        nil ->
          case Map.get(params, "event") || Map.get(params, :event) do
            nil -> []
            event -> [event]
          end

        list ->
          list
      end

    events
    |> Enum.filter(&is_map/1)
    |> Enum.map(&normalize_event/1)
  end

  defp normalize_event(event) when is_map(event) do
    %{
      ts: Map.get(event, "ts") || Map.get(event, :ts) || DateTime.utc_now(),
      type: Map.get(event, "type") || Map.get(event, :type) || "channel.message.received",
      source: Map.get(event, "source") || Map.get(event, :source) || "channel",
      payload:
        Map.get(event, "payload") || Map.get(event, :payload) || Map.get(event, "data") ||
          Map.get(event, :data) || %{}
    }
  end

  defp normalize_event(_event), do: %{}
end
