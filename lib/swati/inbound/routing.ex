defmodule Swati.Inbound.Routing do
  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Inbound.AgentRule
  alias Swati.Inbound.Queries
  alias Swati.Sessions

  def resolve_route(connector, envelope) do
    with {:ok, endpoint} <- resolve_endpoint(connector, envelope),
         thread_key <- thread_key(envelope),
         continuity <- continuity(endpoint, thread_key),
         {:ok, owner_agent_id, route_reason, watcher_agent_ids, matched_rule_ids,
          owner_candidates} <-
           pick_owner(connector, endpoint, envelope, continuity) do
      {:ok,
       %{
         endpoint: endpoint,
         thread_key: thread_key,
         owner_agent_id: owner_agent_id,
         watcher_agent_ids: watcher_agent_ids,
         matched_rule_ids: matched_rule_ids,
         owner_candidates: owner_candidates,
         continuity: continuity,
         route_reason: route_reason
       }}
    end
  end

  defp resolve_endpoint(connector, envelope) do
    to_addresses = normalize_email_list(Map.get(envelope, "to"))

    endpoint =
      Enum.find_value(to_addresses, fn address ->
        Channels.get_endpoint_by_channel_key(connector.tenant_id, "email", address)
      end)

    endpoint = endpoint || resolve_default_endpoint(connector, to_addresses)

    if endpoint do
      {:ok, endpoint}
    else
      {:error, :endpoint_not_found}
    end
  end

  defp resolve_default_endpoint(connector, to_addresses) do
    default_address =
      connector.default_endpoint_address
      |> case do
        nil -> List.first(to_addresses)
        address -> normalize_email(address)
      end

    if is_binary(default_address) and default_address != "" do
      attrs =
        if is_binary(connector.default_agent_id) do
          %{routing_policy: %{"default_agent_id" => connector.default_agent_id}}
        else
          %{}
        end

      case Channels.ensure_endpoint_for_email(connector.tenant_id, default_address, attrs) do
        {:ok, endpoint} -> endpoint
        _ -> nil
      end
    else
      nil
    end
  end

  defp continuity(endpoint, thread_key) do
    session = Sessions.get_session_by_external_id(endpoint.tenant_id, endpoint.id, thread_key)

    if session do
      %{
        hit: true,
        session_id: session.id,
        case_id: session.case_id,
        agent_id: session.agent_id,
        strategy: "session_external_id"
      }
    else
      %{hit: false, strategy: "none"}
    end
  end

  defp pick_owner(_connector, _endpoint, _envelope, %{hit: true, agent_id: agent_id})
       when is_binary(agent_id) do
    {:ok, agent_id, "continuity", [], [], []}
  end

  defp pick_owner(connector, endpoint, envelope, _continuity) do
    matched_rules =
      connector.tenant_id
      |> Queries.list_enabled_rules()
      |> matching_rules(envelope)

    matched_rule_ids = Enum.map(matched_rules, fn %{rule: rule} -> rule.id end)
    watcher_agent_ids = collect_watcher_agent_ids(matched_rules)

    owner_candidates =
      matched_rules
      |> Enum.filter(fn %{rule: rule} -> rule.action == :owner end)
      |> Enum.map(fn %{rule: rule, specificity: specificity} ->
        %{
          "rule_id" => rule.id,
          "agent_id" => rule.agent_id,
          "priority" => rule.priority,
          "specificity" => specificity
        }
      end)

    endpoint_default =
      endpoint.routing_policy
      |> case do
        map when is_map(map) ->
          Map.get(map, "default_agent_id") || Map.get(map, :default_agent_id)

        _ ->
          nil
      end

    cond do
      is_binary(endpoint_default) and endpoint_default != "" ->
        {:ok, endpoint_default, "endpoint_default", watcher_agent_ids, matched_rule_ids,
         owner_candidates}

      true ->
        case Enum.find(matched_rules, fn %{rule: rule} -> rule.action == :owner end) do
          %{rule: %AgentRule{agent_id: agent_id, id: rule_id}} ->
            {:ok, agent_id, "rule:#{rule_id}", watcher_agent_ids, matched_rule_ids,
             owner_candidates}

          _ ->
            case fallback_owner(connector) do
              {:ok, agent_id, reason} ->
                {:ok, agent_id, reason, watcher_agent_ids, matched_rule_ids, owner_candidates}

              {:error, reason} ->
                {:error, reason}
            end
        end
    end
  end

  defp fallback_owner(connector) do
    cond do
      is_binary(connector.default_agent_id) and connector.default_agent_id != "" ->
        {:ok, connector.default_agent_id, "connector_default"}

      true ->
        connector.tenant_id
        |> Agents.list_agents()
        |> Enum.find(&(&1.status == "active" and &1.published_version_id))
        |> case do
          nil -> {:error, :agent_not_found}
          agent -> {:ok, agent.id, "tenant_fallback"}
        end
    end
  end

  defp matching_rules(rules, envelope) do
    rules
    |> Enum.filter(&rule_matches?(&1, envelope))
    |> Enum.map(fn rule ->
      %{rule: rule, specificity: rule_specificity(rule)}
    end)
    |> Enum.sort_by(fn %{rule: rule, specificity: specificity} ->
      {-rule.priority, -specificity, inserted_at_unix(rule), rule.id}
    end)
  end

  defp collect_watcher_agent_ids(matched_rules) do
    matched_rules
    |> Enum.filter(fn %{rule: rule} -> rule.action == :watcher end)
    |> Enum.map(fn %{rule: rule} -> rule.agent_id end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp rule_specificity(%AgentRule{} = rule) do
    predicates = rule.predicates || %{}

    Enum.reduce(predicates, 0, fn {_key, value}, acc ->
      acc + predicate_weight(value)
    end)
  end

  defp predicate_weight(nil), do: 0
  defp predicate_weight(""), do: 0
  defp predicate_weight(value) when is_binary(value), do: 1
  defp predicate_weight(value) when is_list(value), do: max(length(value), 1)
  defp predicate_weight(value) when is_map(value), do: max(map_size(value), 1)
  defp predicate_weight(_value), do: 1

  defp inserted_at_unix(%AgentRule{inserted_at: %DateTime{} = inserted_at}) do
    DateTime.to_unix(inserted_at, :microsecond)
  end

  defp inserted_at_unix(_rule), do: 0

  defp rule_matches?(%AgentRule{} = rule, envelope) do
    predicates = rule.predicates || %{}

    provider_ok = match_provider(predicates, envelope)
    to_ok = match_to(predicates, envelope)
    from_ok = match_from(predicates, envelope)
    subject_ok = match_subject(predicates, envelope)

    provider_ok and to_ok and from_ok and subject_ok
  end

  defp match_provider(predicates, envelope) do
    expected = Map.get(predicates, "provider") || Map.get(predicates, :provider)

    if is_nil(expected) do
      true
    else
      String.downcase(to_string(expected)) ==
        String.downcase(to_string(Map.get(envelope, "provider")))
    end
  end

  defp match_to(predicates, envelope) do
    to = normalize_email_list(Map.get(envelope, "to"))

    addresses =
      predicates
      |> get_predicate(["to_addresses", :to_addresses])
      |> normalize_strings()
      |> Enum.map(&normalize_email/1)
      |> Enum.reject(&(&1 == ""))

    domains =
      predicates
      |> get_predicate(["to_domains", :to_domains])
      |> normalize_strings()
      |> Enum.map(&normalize_domain/1)
      |> Enum.reject(&(&1 == ""))

    address_ok = addresses == [] or Enum.any?(to, &(&1 in addresses))

    domain_ok =
      domains == [] or
        Enum.any?(to, fn address ->
          address_domain(address) in domains
        end)

    address_ok and domain_ok
  end

  defp match_from(predicates, envelope) do
    from = normalize_email(Map.get(envelope, "from") || "")

    allowed =
      predicates
      |> get_predicate(["from_addresses", :from_addresses])
      |> normalize_strings()
      |> Enum.map(&normalize_email/1)
      |> Enum.reject(&(&1 == ""))

    blocked =
      predicates
      |> get_predicate(["from_not_addresses", :from_not_addresses])
      |> normalize_strings()
      |> Enum.map(&normalize_email/1)
      |> Enum.reject(&(&1 == ""))

    (allowed == [] or from in allowed) and (blocked == [] or from not in blocked)
  end

  defp match_subject(predicates, envelope) do
    subject = String.downcase(to_string(Map.get(envelope, "subject") || ""))

    includes =
      predicates
      |> get_predicate(["subject_contains", :subject_contains])
      |> normalize_strings()
      |> Enum.map(&String.downcase/1)

    excludes =
      predicates
      |> get_predicate(["subject_not_contains", :subject_not_contains])
      |> normalize_strings()
      |> Enum.map(&String.downcase/1)

    include_ok = includes == [] or Enum.any?(includes, &String.contains?(subject, &1))
    exclude_ok = excludes == [] or Enum.all?(excludes, &(not String.contains?(subject, &1)))

    include_ok and exclude_ok
  end

  defp get_predicate(predicates, keys) do
    Enum.find_value(keys, fn key -> Map.get(predicates, key) end)
  end

  defp normalize_strings(nil), do: []

  defp normalize_strings(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.downcase/1)
  end

  defp normalize_strings(value) when is_list(value) do
    value
    |> Enum.map(fn item -> item |> to_string() |> String.trim() |> String.downcase() end)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_strings(_value), do: []

  defp thread_key(envelope) do
    Map.get(envelope, "provider_thread_id") ||
      Map.get(envelope, "in_reply_to") ||
      Map.get(envelope, "message_id") ||
      fallback_thread_key(envelope)
  end

  defp fallback_thread_key(envelope) do
    normalized_subject =
      envelope
      |> Map.get("subject")
      |> to_string()
      |> String.trim()
      |> String.downcase()

    normalized_from = normalize_email(Map.get(envelope, "from") || "")
    normalized_to = normalize_email_list(Map.get(envelope, "to")) |> Enum.sort()

    base = [
      normalized_subject,
      normalized_from,
      Enum.join(normalized_to, ",")
    ]

    base
    |> Enum.join("|")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  defp normalize_domain(value) do
    value
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> String.trim_leading("@")
  end

  defp address_domain(value) do
    value
    |> normalize_email()
    |> String.split("@", parts: 2)
    |> case do
      [_local, domain] -> normalize_domain(domain)
      [domain] -> normalize_domain(domain)
      _ -> ""
    end
  end

  defp normalize_email_list(nil), do: []

  defp normalize_email_list(value) when is_list(value) do
    value
    |> Enum.map(&normalize_email/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_email_list(value), do: normalize_email_list([value])

  defp normalize_email(%{"email" => email}), do: normalize_email(email)
  defp normalize_email(%{email: email}), do: normalize_email(email)

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
end
