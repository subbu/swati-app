defmodule Swati.Sessions.BulkRecommendations do
  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionEvent
  alias Swati.Tenancy

  @default_model "gpt-5-mini"
  @default_prompt "Recommend 2 concrete next actions for these conversations."
  @default_recommendations [
    %{
      "title" => "Prioritize unresolved sessions",
      "reason" => "Open and active sessions are most likely to need a fast human response.",
      "action" => "Send a follow-up and tag high-priority threads first."
    },
    %{
      "title" => "Create a handoff summary",
      "reason" => "A concise summary cuts context-switching time for the next assignee.",
      "action" => "Summarize selected sessions and attach one label for routing."
    }
  ]

  def recommend(tenant_id, session_ids, prompt \\ @default_prompt, opts \\ [])
      when is_list(session_ids) do
    ids =
      session_ids
      |> Enum.uniq()
      |> Enum.take(30)

    if ids == [] do
      {:ok,
       %{"recommendations" => @default_recommendations, "suggested_prompt" => @default_prompt}}
    else
      sessions = fetch_sessions(tenant_id, ids)

      if sessions == [] do
        {:ok,
         %{
           "recommendations" => @default_recommendations,
           "suggested_prompt" => normalize_prompt(prompt)
         }}
      else
        events_by_session = fetch_events_by_session(Enum.map(sessions, & &1.id))
        context_payload = build_context_payload(sessions, events_by_session)

        case request_recommendations(context_payload, normalize_prompt(prompt), opts) do
          {:ok, recommendations} ->
            {:ok, recommendations}

          _ ->
            {:ok, fallback_recommendations(sessions, normalize_prompt(prompt))}
        end
      end
    end
  end

  defp fetch_sessions(tenant_id, ids) do
    Session
    |> Tenancy.scope(tenant_id)
    |> where([s], s.id in ^ids)
    |> preload([:agent, :channel, :customer, :endpoint])
    |> Repo.all()
  end

  defp fetch_events_by_session(session_ids) do
    SessionEvent
    |> where([e], e.session_id in ^session_ids)
    |> order_by([e], asc: e.session_id, asc: e.ts)
    |> Repo.all()
    |> Enum.group_by(& &1.session_id)
  end

  defp build_context_payload(sessions, events_by_session) do
    Enum.map(sessions, fn session ->
      events = Map.get(events_by_session, session.id, [])

      %{
        id: session.id,
        external_id: session.external_id,
        status: to_string(session.status || ""),
        direction: to_string(session.direction || ""),
        started_at: iso8601(session.started_at),
        last_event_at: iso8601(session.last_event_at),
        channel: session.channel && session.channel.name,
        endpoint: session.endpoint && session.endpoint.address,
        customer: session.customer && session.customer.name,
        agent: session.agent && session.agent.name,
        from_address: get_in(session.metadata || %{}, ["from_address"]),
        to_address: get_in(session.metadata || %{}, ["to_address"]),
        conversation_excerpt: conversation_excerpt(events)
      }
    end)
  end

  defp conversation_excerpt(events) do
    events
    |> Enum.filter(&(&1.type in ["transcript", "channel.transcript"]))
    |> Enum.map(fn event ->
      payload = event.payload || %{}
      speaker = payload["tag"] || payload["speaker"] || payload["role"] || "Speaker"
      text = payload["text"] || payload["content"] || ""
      text = text |> to_string() |> String.trim() |> truncate(180)

      if text == "", do: nil, else: "#{speaker}: #{text}"
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.take(16)
  end

  defp request_recommendations(context_payload, prompt, opts) do
    with {:ok, api_key} <- openai_api_key(),
         {:ok, response} <- call_openai(api_key, context_payload, prompt, opts),
         {:ok, recommendations} <- parse_openai_response(response) do
      {:ok, recommendations}
    end
  end

  defp openai_api_key do
    case System.get_env("OPENAI_API_KEY") do
      nil -> {:error, :missing_openai_api_key}
      "" -> {:error, :missing_openai_api_key}
      key -> {:ok, key}
    end
  end

  defp call_openai(api_key, context_payload, prompt, opts) do
    system_message =
      """
      You are a support operations assistant. Return strict JSON with:
      - recommendations: array with exactly 2 items
      - each item: title, reason, action (short, concrete)
      - suggested_prompt: one short prompt string
      """

    user_message =
      """
      User prompt:
      #{prompt}

      Session metadata + conversation excerpts:
      #{Jason.encode!(context_payload)}
      """

    body = %{
      model: recommendation_model(opts),
      response_format: %{type: "json_object"},
      temperature: recommendation_temperature(opts),
      messages: [
        %{role: "system", content: system_message},
        %{role: "user", content: user_message}
      ]
    }

    case Req.post("https://api.openai.com/v1/chat/completions",
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ],
           json: body
         ) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, {:openai_http_error, status, resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_openai_response(response) do
    with content when is_binary(content) <-
           get_in(response, ["choices", Access.at(0), "message", "content"]),
         {:ok, decoded} <- Jason.decode(content) do
      recommendations =
        decoded
        |> Map.get("recommendations", [])
        |> Enum.map(&normalize_recommendation/1)
        |> Enum.reject(&(&1["title"] == "" and &1["action"] == ""))
        |> Enum.take(2)

      suggested_prompt =
        decoded
        |> Map.get("suggested_prompt")
        |> normalize_prompt()

      if length(recommendations) == 2 do
        {:ok, %{"recommendations" => recommendations, "suggested_prompt" => suggested_prompt}}
      else
        {:error, :invalid_recommendations_shape}
      end
    else
      _ -> {:error, :invalid_openai_response}
    end
  end

  defp fallback_recommendations(sessions, prompt) do
    open_count =
      Enum.count(sessions, fn session ->
        to_string(session.status || "") in ["open", "active", "waiting_on_customer"]
      end)

    %{
      "recommendations" => [
        %{
          "title" => "Follow up on #{open_count} unresolved sessions",
          "reason" => "These conversations are still open and likely to impact response SLAs.",
          "action" => "Send follow-up messages first for active and waiting sessions."
        },
        %{
          "title" => "Tag and summarize before handoff",
          "reason" => "Consistent labels and summaries reduce triage time for the next owner.",
          "action" => "Apply a common label, then summarize selected sessions for routing."
        }
      ],
      "suggested_prompt" => prompt
    }
  end

  defp normalize_recommendation(item) do
    %{
      "title" => item |> Map.get("title", "") |> to_string() |> String.trim() |> truncate(90),
      "reason" => item |> Map.get("reason", "") |> to_string() |> String.trim() |> truncate(220),
      "action" => item |> Map.get("action", "") |> to_string() |> String.trim() |> truncate(220)
    }
  end

  defp normalize_prompt(nil), do: @default_prompt

  defp normalize_prompt(prompt) do
    prompt
    |> to_string()
    |> String.trim()
    |> case do
      "" -> @default_prompt
      value -> truncate(value, 240)
    end
  end

  defp recommendation_model(opts) do
    case opts[:model] do
      value when is_binary(value) and value != "" -> value
      _ -> System.get_env("OPENAI_REASONING_MODEL") || @default_model
    end
  end

  defp recommendation_temperature(opts) do
    case opts[:temperature] do
      value when is_number(value) ->
        value
        |> max(0.0)
        |> min(1.0)

      _ ->
        0.2
    end
  end

  defp truncate(text, max) when is_binary(text) and byte_size(text) > max do
    binary_part(text, 0, max - 1) <> "…"
  end

  defp truncate(text, _max), do: text

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
