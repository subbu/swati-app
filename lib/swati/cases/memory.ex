defmodule Swati.Cases.Memory do
  @spec empty() :: map()
  def empty do
    %{
      "summary" => nil,
      "commitments" => [],
      "constraints" => [],
      "next_actions" => []
    }
  end

  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: empty()

  def normalize(memory) when is_map(memory) do
    empty()
    |> Map.merge(memory)
  end

  @spec update_from_events(map() | nil, list()) :: map()
  def update_from_events(memory, events) when is_list(events) do
    memory = normalize(memory)
    summary = Map.get(memory, "summary")

    memory =
      Enum.reduce(events, memory, fn event, acc ->
        {type, payload} = normalize_event(event)
        apply_event(acc, type, payload)
      end)

    if is_nil(summary) or summary == "" do
      Map.put(memory, "summary", summarize_events(events))
    else
      memory
    end
  end

  defp normalize_event(event) do
    type = Map.get(event, :type) || Map.get(event, "type")
    payload = Map.get(event, :payload) || Map.get(event, "payload") || %{}
    {type, payload}
  end

  defp apply_event(memory, "case.memory.update", payload) when is_map(payload) do
    Map.merge(memory, payload)
  end

  defp apply_event(memory, "case.commitment.add", payload) when is_map(payload) do
    commitment = Map.get(payload, "commitment") || Map.get(payload, :commitment)

    if is_nil(commitment) do
      memory
    else
      Map.update(memory, "commitments", [commitment], fn items -> items ++ [commitment] end)
    end
  end

  defp apply_event(memory, "case.next_action.add", payload) when is_map(payload) do
    action = Map.get(payload, "action") || Map.get(payload, :action)

    if is_nil(action) do
      memory
    else
      Map.update(memory, "next_actions", [action], fn items -> items ++ [action] end)
    end
  end

  defp apply_event(memory, _type, _payload), do: memory

  defp summarize_events(events) do
    messages =
      events
      |> Enum.flat_map(&event_text/1)
      |> Enum.take(10)

    case messages do
      [] -> nil
      _ -> Enum.join(messages, " ")
    end
  end

  defp event_text(event) do
    type = Map.get(event, :type) || Map.get(event, "type")
    payload = Map.get(event, :payload) || Map.get(event, "payload") || %{}
    text = Map.get(payload, "text") || Map.get(payload, :text)

    if type in [
         "channel.message.received",
         "channel.message.sent",
         "channel.transcript",
         "transcript"
       ] and
         is_binary(text) and text != "" do
      [text]
    else
      []
    end
  end
end
