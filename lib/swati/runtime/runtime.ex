defmodule Swati.Runtime do
  alias Swati.Agents
  alias Swati.Agents.EscalationPolicy
  alias Swati.Agents.ToolPolicy
  alias Swati.Channels
  alias Swati.Channels.ToolAllowlist, as: ChannelToolAllowlist
  alias Swati.Cases
  alias Swati.Customers
  alias Swati.Integrations
  alias Swati.Integrations.Serialization
  alias Swati.Repo
  alias Swati.RuntimeConfig
  alias Swati.Sessions
  alias Swati.Sessions.Events, as: SessionEvents
  alias Swati.Tenancy
  alias Swati.Webhooks
  alias Swati.Webhooks.Serialization, as: WebhookSerialization

  @spec resolve_runtime(map()) :: {:ok, map()} | {:error, atom()}
  def resolve_runtime(params) when is_map(params) do
    with {:ok, endpoint, channel} <- resolve_endpoint(params),
         tenant <- Tenancy.get_tenant!(endpoint.tenant_id),
         {:ok, customer, _identity} <- resolve_customer(tenant.id, channel, params),
         {:ok, case_record} <- resolve_case(tenant.id, customer, params),
         {:ok, session} <-
           resolve_session(tenant.id, channel, endpoint, customer, case_record, params),
         {:ok, agent, version} <- resolve_agent(tenant.id, endpoint, case_record) do
      {integrations, webhooks} = resolve_tools(tenant.id, channel.id, agent.id)
      channel_tools = ChannelToolAllowlist.allowed_tools(channel)
      tool_policy = ToolPolicy.effective(version.config, integrations, webhooks, channel_tools)

      integrations_json =
        Enum.map(integrations, fn {integration, secret} ->
          Serialization.internal_payload(integration, secret)
        end)

      webhooks_json =
        Enum.map(webhooks, fn {webhook, secret} ->
          WebhookSerialization.internal_payload(webhook, secret)
        end)

      {:ok,
       %{
         config_version: RuntimeConfig.version(),
         tenant: %{id: tenant.id, name: tenant.name, timezone: tenant.timezone},
         channel: channel_payload(channel),
         endpoint: endpoint_payload(endpoint),
         customer: customer_payload(customer),
         case: case_payload(case_record),
         session: session_payload(session),
         agent: agent_payload(agent, version.config, tool_policy),
         integrations: integrations_json,
         webhooks: webhooks_json,
         logging: %{
           recording: %{
             enabled: true,
             record_caller: true,
             record_agent: true,
             generate_stereo: true
           },
           retention_days: 30
         }
       }}
    end
  rescue
    Ecto.NoResultsError -> {:error, :endpoint_not_found}
  end

  defp resolve_endpoint(params) do
    endpoint_id = param(params, [:endpoint_id]) || nested_param(params, ["endpoint", "id"])

    cond do
      is_binary(endpoint_id) ->
        endpoint = Repo.get(Swati.Channels.Endpoint, endpoint_id) |> Repo.preload(:channel)

        if endpoint && endpoint.channel,
          do: {:ok, endpoint, endpoint.channel},
          else: {:error, :endpoint_not_found}

      true ->
        address =
          string_value(param(params, [:endpoint_address, :address, :to_address])) ||
            string_value(nested_param(params, ["endpoint", "address"]))

        channel_key =
          string_value(param(params, [:channel_key])) ||
            string_value(nested_param(params, ["channel", "key"]))

        channel_type =
          string_value(param(params, [:channel_type])) ||
            string_value(nested_param(params, ["channel", "type"]))

        endpoint =
          cond do
            is_binary(channel_key) and is_binary(address) ->
              Channels.get_endpoint_by_channel_key(channel_key, address)

            is_binary(channel_type) and is_binary(address) ->
              Channels.get_endpoint_by_channel_type(channel_type, address)

            true ->
              nil
          end

        if endpoint && endpoint.channel do
          {:ok, endpoint, endpoint.channel}
        else
          {:error, :endpoint_not_found}
        end
    end
  end

  defp resolve_customer(tenant_id, channel, params) do
    kind =
      param(params, [:customer_kind]) || nested_param(params, ["customer", "kind"]) ||
        default_kind_for_channel(channel.type)

    kind = customer_kind(kind)

    address =
      param(params, [:from_address, :customer_address]) ||
        nested_param(params, ["customer", "address"])

    external_id =
      param(params, [:customer_external_id]) || nested_param(params, ["customer", "external_id"])

    if is_nil(address) and is_nil(external_id) do
      {:error, :customer_identity_missing}
    else
      Customers.resolve_customer(tenant_id, channel.id, kind, %{
        address: address,
        external_id: external_id,
        name: param(params, [:customer_name]) || nested_param(params, ["customer", "name"]),
        timezone:
          param(params, [:customer_timezone]) || nested_param(params, ["customer", "timezone"]),
        language:
          param(params, [:customer_language]) || nested_param(params, ["customer", "language"])
      })
    end
  end

  defp resolve_case(tenant_id, customer, params) do
    category = param(params, [:case_category]) || nested_param(params, ["case", "category"])

    case_record = Cases.find_open_case_for_customer(tenant_id, customer.id, category)

    case case_record do
      %Swati.Cases.Case{} = record ->
        {:ok, record}

      nil ->
        title = param(params, [:case_title]) || nested_param(params, ["case", "title"])

        Cases.create_case(tenant_id, %{
          customer_id: customer.id,
          category: category,
          title: title
        })
    end
  end

  defp resolve_session(tenant_id, channel, endpoint, customer, case_record, params) do
    external_id =
      param(params, [:session_external_id, :external_id]) ||
        nested_param(params, ["session", "external_id"])

    session =
      if is_binary(external_id) do
        Sessions.get_session_by_external_id(tenant_id, endpoint.id, external_id)
      else
        nil
      end

    case session do
      %Swati.Sessions.Session{} = session ->
        {:ok, session}

      nil ->
        started_at =
          param(params, [:started_at]) ||
            nested_param(params, ["session", "started_at"]) ||
            nested_param(params, ["event", "ts"])

        direction =
          param(params, [:direction]) ||
            nested_param(params, ["session", "direction"]) ||
            "inbound"

        subject = param(params, [:subject]) || nested_param(params, ["session", "subject"])

        metadata = %{
          "from_address" =>
            param(params, [:from_address]) || nested_param(params, ["customer", "address"]),
          "to_address" =>
            param(params, [:endpoint_address, :address]) ||
              nested_param(params, ["endpoint", "address"]),
          "provider" =>
            param(params, [:provider]) || nested_param(params, ["session", "provider"])
        }

        Sessions.create_session(tenant_id, %{
          channel_id: channel.id,
          endpoint_id: endpoint.id,
          customer_id: customer.id,
          case_id: case_record.id,
          direction: normalize_direction(direction),
          external_id: external_id,
          subject: subject,
          started_at: SessionEvents.parse_datetime(started_at),
          metadata: metadata
        })
    end
  end

  defp resolve_agent(tenant_id, endpoint, case_record) do
    routing_policy = endpoint.routing_policy || %{}

    default_agent_id =
      Map.get(routing_policy, "default_agent_id") || Map.get(routing_policy, :default_agent_id)

    agent_id =
      default_agent_id ||
        case_record.assigned_agent_id ||
        pick_fallback_agent_id(tenant_id)

    if is_nil(agent_id) do
      {:error, :agent_missing}
    else
      agent = Agents.get_agent!(tenant_id, agent_id)

      case agent.published_version do
        nil ->
          {:error, :agent_not_published}

        version ->
          _ = maybe_assign_case_agent(case_record, agent.id)
          {:ok, agent, version}
      end
    end
  end

  defp resolve_tools(tenant_id, channel_id, agent_id) do
    integrations = Integrations.list_integrations_with_secrets(tenant_id, agent_id)
    webhooks = Webhooks.list_webhooks_with_secrets(tenant_id, agent_id)

    integration_ids = Channels.list_channel_integration_ids(channel_id)
    webhook_ids = Channels.list_channel_webhook_ids(channel_id)

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

  defp pick_fallback_agent_id(tenant_id) do
    tenant_id
    |> Agents.list_agents()
    |> Enum.find(&(&1.status == "active" and &1.published_version_id))
    |> case do
      nil -> nil
      agent -> agent.id
    end
  end

  defp maybe_assign_case_agent(case_record, agent_id) do
    if is_nil(case_record.assigned_agent_id) do
      _ = Cases.update_case(case_record, %{assigned_agent_id: agent_id})
    end
  end

  defp channel_payload(channel) do
    %{
      id: channel.id,
      name: channel.name,
      key: channel.key,
      type: channel.type,
      status: channel.status,
      capabilities: channel.capabilities || %{}
    }
  end

  defp endpoint_payload(endpoint) do
    %{
      id: endpoint.id,
      address: endpoint.address,
      display_name: endpoint.display_name,
      status: endpoint.status,
      routing_policy: endpoint.routing_policy || %{},
      metadata: endpoint.metadata || %{}
    }
  end

  defp customer_payload(customer) do
    %{
      id: customer.id,
      name: customer.name,
      timezone: customer.timezone,
      language: customer.language,
      preferences: customer.preferences || %{}
    }
  end

  defp case_payload(case_record) do
    %{
      id: case_record.id,
      status: case_record.status,
      priority: case_record.priority,
      category: case_record.category,
      title: case_record.title,
      summary: case_record.summary,
      memory: case_record.memory || %{}
    }
  end

  defp session_payload(session) do
    %{
      id: session.id,
      status: session.status,
      direction: session.direction,
      external_id: session.external_id,
      subject: session.subject
    }
  end

  defp agent_payload(agent, config, tool_policy) do
    config = config || %{}

    %{
      id: agent.id,
      name: agent.name,
      language: Map.get(config, "language") || agent.language,
      voice:
        Map.get(config, "voice") || %{provider: agent.voice_provider, name: agent.voice_name},
      llm: Map.get(config, "llm") || %{provider: agent.llm_provider, model: agent.llm_model},
      system_prompt: Map.get(config, "system_prompt"),
      tool_policy: tool_policy,
      escalation_policy: EscalationPolicy.normalize(Map.get(config, "escalation_policy"))
    }
  end

  defp default_kind_for_channel(:voice), do: :phone
  defp default_kind_for_channel(:email), do: :email
  defp default_kind_for_channel(:whatsapp), do: :phone
  defp default_kind_for_channel(:chat), do: :handle
  defp default_kind_for_channel(_type), do: :external

  defp customer_kind(nil), do: :external

  defp customer_kind(kind) when is_atom(kind) do
    kind
  end

  defp customer_kind(kind) when is_binary(kind) do
    case kind do
      "phone" -> :phone
      "email" -> :email
      "handle" -> :handle
      _ -> :external
    end
  end

  defp normalize_direction(direction) when is_atom(direction), do: direction

  defp normalize_direction(direction) when is_binary(direction) do
    case direction do
      "outbound" -> :outbound
      _ -> :inbound
    end
  end

  defp param(params, keys) do
    Enum.find_value(keys, fn key ->
      Map.get(params, key) || Map.get(params, to_string(key))
    end)
  end

  defp string_value(value) when is_binary(value) and value != "", do: value
  defp string_value(value) when is_atom(value), do: Atom.to_string(value)
  defp string_value(_value), do: nil

  defp nested_param(params, path) do
    Enum.reduce(path, params, fn key, acc ->
      cond do
        is_nil(acc) -> nil
        is_map(acc) -> Map.get(acc, key) || Map.get(acc, to_string(key))
        true -> nil
      end
    end)
  end
end
