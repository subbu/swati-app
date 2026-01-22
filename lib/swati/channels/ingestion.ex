defmodule Swati.Channels.Ingestion do
  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Channels.ToolAllowlist, as: ChannelToolAllowlist
  alias Swati.Integrations
  alias Swati.Policies.ToolPolicy, as: EffectiveToolPolicy
  alias Swati.Repo
  alias Swati.Runtime
  alias Swati.Sessions
  alias Swati.Sessions.Session
  alias Swati.Tenancy
  alias Swati.Webhooks

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
      tool_name = tool_name(params)

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

      case fetch_session(session_id) do
        nil ->
          {:error, :session_not_found}

        %Session{} = session ->
          with :ok <- authorize_channel_tool(session, tool_name) do
            case maybe_send(session, payload, params) do
              {:ok, updated_payload} ->
                event = build_event(params, updated_payload)
                :ok = Sessions.append_events(session.id, [event])
                {:ok, %{session_id: session.id}}

              :ok ->
                event = build_event(params, payload)
                :ok = Sessions.append_events(session.id, [event])
                {:ok, %{session_id: session.id}}

              {:error, reason} ->
                {:error, reason}
            end
          end
      end
    end
  end

  defp build_event(params, payload) do
    %{
      ts: Map.get(params, "ts") || Map.get(params, :ts) || DateTime.utc_now(),
      type: Map.get(params, "type") || Map.get(params, :type) || "channel.message.sent",
      source: Map.get(params, "source") || Map.get(params, :source) || "channel",
      payload: payload
    }
  end

  defp maybe_send(session, payload, params) do
    if session && session.channel && session.channel.type == :email do
      with {:ok, connection} <- fetch_connection(session),
           {:ok, message} <- build_email_message(session, payload, params),
           {:ok, response} <- Channels.send_message(connection, message) do
        updated_payload = Map.put(payload, "provider_response", response)
        {:ok, updated_payload}
      end
    else
      :ok
    end
  end

  defp fetch_connection(session) do
    case Channels.get_connection_by_endpoint(session.tenant_id, session.endpoint_id) do
      nil -> {:error, :channel_connection_missing}
      connection -> {:ok, Repo.preload(connection, :endpoint)}
    end
  end

  defp build_email_message(session, payload, params) do
    to =
      Map.get(payload, "to") || Map.get(payload, :to) || Map.get(payload, "to_address") ||
        Map.get(payload, :to_address) || Map.get(params, "to") || Map.get(params, :to) ||
        default_recipient(session)

    subject =
      Map.get(payload, "subject") || Map.get(payload, :subject) || Map.get(params, "subject") ||
        Map.get(params, :subject) || session.subject || "New message"

    text =
      Map.get(payload, "text") || Map.get(payload, :text) || Map.get(payload, "body") ||
        Map.get(payload, :body) || Map.get(params, "text") || Map.get(params, :text)

    if is_nil(to) or is_nil(text) or text == "" do
      {:error, :message_payload_invalid}
    else
      {:ok,
       %{
         "to" => to,
         "subject" => subject,
         "text" => text,
         "thread_id" => session.external_id
       }}
    end
  end

  defp default_recipient(session) do
    metadata = session.metadata || %{}
    from_address = Map.get(metadata, "from_address")
    to_address = Map.get(metadata, "to_address")

    case session.direction do
      :inbound -> from_address
      :outbound -> to_address || from_address
      _ -> from_address || to_address
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

  defp fetch_session(session_id) do
    Session
    |> Repo.get(session_id)
    |> Repo.preload([:channel, :endpoint, :customer, :case])
  end

  defp authorize_channel_tool(%Session{} = session, tool_name) do
    with {:ok, agent, version} <- resolve_agent_for_session(session),
         :ok <- Agents.authorize_agent_channel(agent.id, session.channel_id, session.endpoint_id),
         {:ok, tool_policy} <- build_tool_policy(session, agent, version),
         true <- tool_allowed?(tool_policy, tool_name) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :tool_not_allowed}
    end
  end

  defp resolve_agent_for_session(%Session{} = session) do
    agent_id =
      session.agent_id ||
        case session.case do
          %{assigned_agent_id: assigned_agent_id} -> assigned_agent_id
          _ -> nil
        end

    if is_nil(agent_id) do
      {:error, :agent_missing}
    else
      agent = Agents.get_agent!(session.tenant_id, agent_id) |> Repo.preload(:published_version)

      case agent.published_version do
        nil -> {:error, :agent_not_published}
        version -> {:ok, agent, version}
      end
    end
  end

  defp build_tool_policy(%Session{} = session, agent, version) do
    tenant = Tenancy.get_tenant!(session.tenant_id)

    channel_tools =
      agent.id
      |> Agents.list_agent_channels()
      |> Enum.filter(& &1.enabled)
      |> Enum.flat_map(fn agent_channel ->
        if agent_channel.channel do
          ChannelToolAllowlist.allowed_tools(agent_channel.channel)
        else
          []
        end
      end)
      |> Enum.uniq()

    {integrations, webhooks} = resolve_tools_for_session(session, agent)

    policy =
      EffectiveToolPolicy.effective(
        version.config,
        integrations,
        webhooks,
        channel_tools,
        [tenant.policy, session.channel.policy, session.case && session.case.policy]
      )

    {:ok, policy}
  end

  defp resolve_tools_for_session(%Session{} = session, agent) do
    integrations = Integrations.list_integrations_with_secrets(session.tenant_id, agent.id)
    webhooks = Webhooks.list_webhooks_with_secrets(session.tenant_id, agent.id)

    integration_ids = Channels.list_channel_integration_ids(session.channel_id)
    webhook_ids = Channels.list_channel_webhook_ids(session.channel_id)

    integrations =
      if integration_ids == [] do
        integrations
      else
        Enum.filter(integrations, fn {integration, _secret} ->
          integration.id in integration_ids
        end)
      end

    webhooks =
      if webhook_ids == [] do
        webhooks
      else
        Enum.filter(webhooks, fn {webhook, _secret} -> webhook.id in webhook_ids end)
      end

    {integrations, webhooks}
  end

  defp tool_allowed?(policy, tool_name) do
    allowlist = Map.get(policy || %{}, "allow", [])
    to_string(tool_name) in allowlist
  end

  defp tool_name(params) do
    Map.get(params, "tool_name") || Map.get(params, :tool_name) || "channel.message.send"
  end
end
