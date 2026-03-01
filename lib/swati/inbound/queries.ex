defmodule Swati.Inbound.Queries do
  import Ecto.Query, warn: false

  alias Swati.Inbound.AgentRule
  alias Swati.Inbound.Connector
  alias Swati.Inbound.Delivery
  alias Swati.Inbound.ThreadOwnershipEvent
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions.Session
  alias Swati.Sessions.SessionEvent
  alias Swati.Tenancy

  def list_connectors(tenant_id) do
    Connector
    |> Tenancy.scope(tenant_id)
    |> order_by([c], asc: c.name)
    |> preload([:default_agent])
    |> Repo.all()
  end

  def list_email_bindings(tenant_id) do
    from(e in Endpoint,
      where: e.tenant_id == ^tenant_id,
      join: ch in assoc(e, :channel),
      where: ch.key == "email",
      preload: [channel: ch],
      order_by: [asc: e.address]
    )
    |> Repo.all()
  end

  def get_connector!(tenant_id, connector_id) do
    Connector
    |> Tenancy.scope(tenant_id)
    |> preload([:default_agent])
    |> Repo.get!(connector_id)
  end

  def get_connector_by_token(token) when is_binary(token) do
    Connector
    |> where([c], c.endpoint_token == ^token)
    |> preload([:default_agent])
    |> Repo.one()
  end

  def list_rules(tenant_id) do
    AgentRule
    |> Tenancy.scope(tenant_id)
    |> preload([:agent])
    |> order_by([r], desc: r.priority, asc: r.inserted_at)
    |> Repo.all()
  end

  def list_enabled_rules(tenant_id) do
    AgentRule
    |> Tenancy.scope(tenant_id)
    |> where([r], r.enabled == true)
    |> preload([:agent])
    |> order_by([r], desc: r.priority, asc: r.inserted_at)
    |> Repo.all()
  end

  def get_rule!(tenant_id, rule_id) do
    AgentRule
    |> Tenancy.scope(tenant_id)
    |> Repo.get!(rule_id)
  end

  def get_delivery!(tenant_id, delivery_id) do
    Delivery
    |> Tenancy.scope(tenant_id)
    |> preload([:connector])
    |> Repo.get!(delivery_id)
  end

  def get_delivery(delivery_id) do
    Delivery
    |> where([d], d.id == ^delivery_id)
    |> preload([:connector])
    |> Repo.one()
  end

  def list_deliveries(tenant_id, opts \\ []) do
    limit = max(1, min(Keyword.get(opts, :limit, 100), 500))
    filters = Keyword.get(opts, :filters, %{})

    Delivery
    |> Tenancy.scope(tenant_id)
    |> maybe_filter_delivery(:status, filters)
    |> maybe_filter_delivery(:connector_id, filters)
    |> maybe_filter_delivery(:session_id, filters)
    |> maybe_filter_delivery(:case_id, filters)
    |> maybe_filter_delivery(:from_address, filters)
    |> maybe_filter_delivery_query(filters)
    |> preload([:connector])
    |> order_by([d], desc: d.received_at, desc: d.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def list_deliveries_for_session(tenant_id, session_id) when is_binary(session_id) do
    Delivery
    |> Tenancy.scope(tenant_id)
    |> where([d], fragment("?->>?", d.runtime_result, "session_id") == ^session_id)
    |> preload([:connector])
    |> order_by([d], desc: d.received_at)
    |> Repo.all()
  end

  def list_email_sessions(tenant_id, opts \\ []) do
    limit = max(1, min(Keyword.get(opts, :limit, 100), 500))

    from(s in Swati.Sessions.Session,
      where: s.tenant_id == ^tenant_id,
      join: ch in assoc(s, :channel),
      where: ch.type == :email,
      preload: [:agent, :case, :customer, :endpoint, :channel],
      order_by: [desc: s.last_event_at, desc: s.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def get_email_session(tenant_id, session_id) do
    from(s in Swati.Sessions.Session,
      where: s.tenant_id == ^tenant_id and s.id == ^session_id,
      join: ch in assoc(s, :channel),
      where: ch.type == :email,
      preload: [
        :agent,
        :case,
        :customer,
        :endpoint,
        :channel,
        events: ^from(e in Swati.Sessions.SessionEvent, order_by: [asc: e.ts])
      ]
    )
    |> Repo.one()
  end

  def list_thread_ownership_events_for_session(tenant_id, session_id, opts \\ []) do
    limit = max(1, min(Keyword.get(opts, :limit, 100), 500))

    ThreadOwnershipEvent
    |> Tenancy.scope(tenant_id)
    |> where([e], e.session_id == ^session_id)
    |> preload([:owner_agent, :previous_agent, :delivery])
    |> order_by([e], desc: e.resolved_at, desc: e.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def latest_thread_ownership_event_for_session(tenant_id, session_id) do
    ThreadOwnershipEvent
    |> Tenancy.scope(tenant_id)
    |> where([e], e.session_id == ^session_id)
    |> order_by([e], desc: e.resolved_at, desc: e.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def list_email_messages(tenant_id, opts \\ []) do
    limit = max(1, min(Keyword.get(opts, :limit, 100), 500))
    filters = Keyword.get(opts, :filters, %{})

    SessionEvent
    |> join(:inner, [e], s in Session, on: s.id == e.session_id)
    |> join(:inner, [_e, s], ch in assoc(s, :channel))
    |> join(:left, [_e, s, _ch], agent in assoc(s, :agent))
    |> join(:left, [_e, s, _ch, _agent], case_record in assoc(s, :case))
    |> join(:left, [_e, s, _ch, _agent, _case], customer in assoc(s, :customer))
    |> join(:left, [_e, s, _ch, _agent, _case, _customer], endpoint in assoc(s, :endpoint))
    |> where([_e, s, ch], s.tenant_id == ^tenant_id and ch.type == :email)
    |> where([e], e.type in ["channel.message.received", "channel.message.sent"])
    |> maybe_filter_message(:session_id, filters)
    |> maybe_filter_message(:agent_id, filters)
    |> maybe_filter_message(:case_id, filters)
    |> maybe_filter_message(:direction, filters)
    |> maybe_filter_message_query(filters)
    |> order_by([e], desc: e.ts, desc: e.inserted_at)
    |> limit(^limit)
    |> select([e, s, _ch, agent, case_record, customer, endpoint], %{
      id: e.id,
      ts: e.ts,
      type: e.type,
      payload: e.payload,
      session_id: s.id,
      session_external_id: s.external_id,
      session_status: s.status,
      endpoint_address: endpoint.address,
      case_id: case_record.id,
      customer_email: customer.primary_email,
      agent_id: agent.id,
      agent_name: agent.name
    })
    |> Repo.all()
  end

  defp maybe_filter_delivery(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    cond do
      value in [nil, ""] ->
        query

      key == :status ->
        from(d in query, where: fragment("?::text = ?", d.status, ^to_string(value)))

      key == :session_id ->
        from(d in query, where: fragment("?->>?", d.runtime_result, "session_id") == ^value)

      key == :case_id ->
        from(d in query, where: fragment("?->>?", d.runtime_result, "case_id") == ^value)

      key == :from_address ->
        from(d in query,
          where: fragment("lower(?->>?) = lower(?)", d.normalized_payload, "from", ^value)
        )

      true ->
        from(record in query, where: field(record, ^key) == ^value)
    end
  end

  defp maybe_filter_delivery_query(query, filters) do
    term = Map.get(filters, :query) || Map.get(filters, "query")

    if is_nil(term) or String.trim(to_string(term)) == "" do
      query
    else
      like = "%#{String.trim(to_string(term))}%"

      from(d in query,
        where:
          ilike(fragment("coalesce(?->>?, '')", d.normalized_payload, "subject"), ^like) or
            ilike(fragment("coalesce(?->>?, '')", d.normalized_payload, "from"), ^like) or
            ilike(fragment("coalesce(?::text, '')", d.normalized_payload), ^like)
      )
    end
  end

  defp maybe_filter_message(query, key, filters) do
    value = Map.get(filters, key) || Map.get(filters, to_string(key))

    if value in [nil, ""] do
      query
    else
      case key do
        :session_id ->
          from([_e, s, _ch, _agent, _case_record, _customer, _endpoint] in query,
            where: s.id == ^value
          )

        :agent_id ->
          from([_e, s, _ch, _agent, _case_record, _customer, _endpoint] in query,
            where: s.agent_id == ^value
          )

        :case_id ->
          from([_e, s, _ch, _agent, _case_record, _customer, _endpoint] in query,
            where: s.case_id == ^value
          )

        :direction ->
          event_type =
            case to_string(value) do
              "inbound" -> "channel.message.received"
              "outbound" -> "channel.message.sent"
              _ -> nil
            end

          if event_type do
            from([e, _s, _ch, _agent, _case_record, _customer, _endpoint] in query,
              where: e.type == ^event_type
            )
          else
            query
          end

        _ ->
          query
      end
    end
  end

  defp maybe_filter_message_query(query, filters) do
    term = Map.get(filters, :query) || Map.get(filters, "query")

    if is_nil(term) or String.trim(to_string(term)) == "" do
      query
    else
      like = "%#{String.trim(to_string(term))}%"

      from([e, s, _ch, _agent, _case_record, customer, endpoint] in query,
        where:
          ilike(fragment("coalesce(?->>?, '')", e.payload, "subject"), ^like) or
            ilike(fragment("coalesce(?->>?, '')", e.payload, "text"), ^like) or
            ilike(fragment("coalesce(?->>?, '')", e.payload, "from"), ^like) or
            ilike(fragment("coalesce(?::text, '')", e.payload), ^like) or
            ilike(fragment("coalesce(?, '')", s.external_id), ^like) or
            ilike(fragment("coalesce(?, '')", customer.primary_email), ^like) or
            ilike(fragment("coalesce(?, '')", endpoint.address), ^like)
      )
    end
  end
end
