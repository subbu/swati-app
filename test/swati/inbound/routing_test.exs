defmodule Swati.Inbound.RoutingTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Inbound
  alias Swati.Inbound.Routing
  alias Swati.Runtime
  alias Swati.Sessions

  test "continuity keeps thread owner in multi-agent tenant" do
    scope = user_scope_fixture()

    {:ok, agent_a} = Agents.create_agent(scope.tenant.id, %{name: "Agent A"}, scope.user)
    {:ok, agent_a, _} = Agents.publish_agent(agent_a, scope.user)

    {:ok, agent_b} = Agents.create_agent(scope.tenant.id, %{name: "Agent B"}, scope.user)
    {:ok, agent_b, _} = Agents.publish_agent(agent_b, scope.user)

    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)
    {:ok, _} = Agents.upsert_agent_channel(agent_a.id, channel.id, true)
    {:ok, _} = Agents.upsert_agent_channel(agent_b.id, channel.id, true)

    support_address = "support-#{System.unique_integer([:positive])}@tenant.test"

    {:ok, endpoint} =
      Channels.ensure_endpoint_for_email(scope.tenant.id, support_address, %{
        routing_policy: %{"default_agent_id" => agent_a.id}
      })

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Resend Connector",
        signing_secret: "whsec_" <> Base.encode64("secret"),
        default_endpoint_address: endpoint.address,
        default_agent_id: agent_a.id
      })

    {:ok, _runtime} =
      Runtime.resolve_runtime(%{
        channel_key: "email",
        endpoint_address: endpoint.address,
        from_address: "customer@x.com",
        customer_kind: "email",
        session_external_id: "thread-xyz",
        direction: "inbound",
        subject: "Initial",
        agent_id: agent_b.id,
        event: %{"type" => "channel.message.received", "payload" => %{"text" => "hello"}}
      })

    session = Sessions.get_session_by_external_id(scope.tenant.id, endpoint.id, "thread-xyz")
    assert session
    assert session.agent_id == agent_b.id

    envelope = %{
      "provider" => "resend",
      "from" => "customer@x.com",
      "to" => [support_address],
      "subject" => "Follow-up",
      "message_id" => "thread-xyz"
    }

    assert {:ok, route} = Routing.resolve_route(connector, envelope)
    assert route.owner_agent_id == agent_b.id
    assert route.route_reason == "continuity"
    assert route.continuity.hit == true
    assert route.continuity.session_id == session.id
  end

  test "rules decide owner when continuity is missing" do
    scope = user_scope_fixture()

    {:ok, agent_a} = Agents.create_agent(scope.tenant.id, %{name: "Agent A"}, scope.user)
    {:ok, agent_a, _} = Agents.publish_agent(agent_a, scope.user)

    {:ok, agent_b} = Agents.create_agent(scope.tenant.id, %{name: "Agent B"}, scope.user)
    {:ok, agent_b, _} = Agents.publish_agent(agent_b, scope.user)

    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)
    {:ok, _} = Agents.upsert_agent_channel(agent_a.id, channel.id, true)
    {:ok, _} = Agents.upsert_agent_channel(agent_b.id, channel.id, true)

    billing_address = "billing-#{System.unique_integer([:positive])}@tenant.test"

    {:ok, endpoint} =
      Channels.ensure_endpoint_for_email(scope.tenant.id, billing_address, %{
        routing_policy: %{}
      })

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Resend Connector Rules",
        signing_secret: "whsec_" <> Base.encode64("secret"),
        default_endpoint_address: endpoint.address,
        default_agent_id: agent_a.id
      })

    {:ok, rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "Billing Rule",
        "agent_id" => agent_b.id,
        "priority" => 900,
        "action" => "owner",
        "predicates" => %{"to_addresses" => [endpoint.address]}
      })

    envelope = %{
      "provider" => "resend",
      "from" => "customer@x.com",
      "to" => [billing_address],
      "subject" => "Billing issue",
      "message_id" => "new-thread-1"
    }

    assert {:ok, route} = Routing.resolve_route(connector, envelope)
    assert route.owner_agent_id == agent_b.id
    assert route.route_reason == "rule:#{rule.id}"
  end

  test "deterministic precedence picks specific owner rule and keeps watchers" do
    scope = user_scope_fixture()

    {:ok, agent_a} = Agents.create_agent(scope.tenant.id, %{name: "Agent A"}, scope.user)
    {:ok, agent_a, _} = Agents.publish_agent(agent_a, scope.user)

    {:ok, agent_b} = Agents.create_agent(scope.tenant.id, %{name: "Agent B"}, scope.user)
    {:ok, agent_b, _} = Agents.publish_agent(agent_b, scope.user)

    {:ok, watcher} = Agents.create_agent(scope.tenant.id, %{name: "Watcher"}, scope.user)
    {:ok, watcher, _} = Agents.publish_agent(watcher, scope.user)

    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)
    {:ok, _} = Agents.upsert_agent_channel(agent_a.id, channel.id, true)
    {:ok, _} = Agents.upsert_agent_channel(agent_b.id, channel.id, true)
    {:ok, _} = Agents.upsert_agent_channel(watcher.id, channel.id, true)

    support_address = "support-#{System.unique_integer([:positive])}@tenant.test"

    {:ok, endpoint} =
      Channels.ensure_endpoint_for_email(scope.tenant.id, support_address, %{
        routing_policy: %{}
      })

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Resend Connector Specificity",
        signing_secret: "whsec_" <> Base.encode64("secret"),
        default_endpoint_address: endpoint.address,
        default_agent_id: agent_a.id
      })

    {:ok, broad_rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "Broad Owner Rule",
        "agent_id" => agent_a.id,
        "priority" => 500,
        "action" => "owner",
        "predicates" => %{"to_domains" => ["tenant.test"]}
      })

    {:ok, specific_rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "Specific Owner Rule",
        "agent_id" => agent_b.id,
        "priority" => 500,
        "action" => "owner",
        "predicates" => %{
          "to_addresses" => [endpoint.address],
          "subject_contains" => ["billing"]
        }
      })

    {:ok, watcher_rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "Watcher Rule",
        "agent_id" => watcher.id,
        "priority" => 1000,
        "action" => "watcher",
        "predicates" => %{"to_addresses" => [endpoint.address]}
      })

    envelope = %{
      "provider" => "resend",
      "from" => "customer@x.com",
      "to" => [support_address],
      "subject" => "Billing escalation",
      "message_id" => "new-thread-2"
    }

    assert {:ok, route} = Routing.resolve_route(connector, envelope)
    assert route.owner_agent_id == agent_b.id
    assert route.route_reason == "rule:#{specific_rule.id}"
    assert watcher.id in route.watcher_agent_ids
    assert watcher_rule.id in route.matched_rule_ids
    assert broad_rule.id in route.matched_rule_ids
    assert specific_rule.id in route.matched_rule_ids
  end

  test "route preview matches realistic display-name and mixed-case email addresses" do
    scope = user_scope_fixture()

    {:ok, owner} = Agents.create_agent(scope.tenant.id, %{name: "Owner"}, scope.user)
    {:ok, owner, _} = Agents.publish_agent(owner, scope.user)

    {:ok, watcher} = Agents.create_agent(scope.tenant.id, %{name: "Watcher"}, scope.user)
    {:ok, watcher, _} = Agents.publish_agent(watcher, scope.user)

    {:ok, channel} = Channels.ensure_email_channel(scope.tenant.id)
    {:ok, _} = Agents.upsert_agent_channel(owner.id, channel.id, true)
    {:ok, _} = Agents.upsert_agent_channel(watcher.id, channel.id, true)

    support_address = "support-#{System.unique_integer([:positive])}@tenant.test"

    {:ok, _endpoint} =
      Channels.ensure_endpoint_for_email(scope.tenant.id, support_address, %{
        routing_policy: %{}
      })

    {:ok, connector} =
      Inbound.create_connector(scope.tenant.id, %{
        name: "Preview Connector",
        signing_secret: "whsec_" <> Base.encode64("secret"),
        default_endpoint_address: support_address
      })

    {:ok, owner_rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "VIP Refund Owner",
        "agent_id" => owner.id,
        "priority" => 800,
        "action" => "owner",
        "predicates" => %{
          "to_addresses" => [support_address],
          "from_addresses" => ["vip@example.com"],
          "subject_contains" => ["refund"]
        }
      })

    {:ok, watcher_rule} =
      Inbound.create_rule(scope.tenant.id, %{
        "name" => "Tenant Domain Watcher",
        "agent_id" => watcher.id,
        "priority" => 700,
        "action" => "watcher",
        "predicates" => %{"to_domains" => ["tenant.test"]}
      })

    params = %{
      "from" => "VIP Customer <VIP@Example.COM>",
      "to" => "Support Team <#{String.upcase(support_address)}>",
      "subject" => "Need REFUND support",
      "message_id" => "preview-thread-1"
    }

    assert {:ok, %{route: route}} = Inbound.preview_route(connector, params)
    assert route.owner_agent_id == owner.id
    assert route.route_reason == "rule:#{owner_rule.id}"
    assert watcher.id in route.watcher_agent_ids
    assert watcher_rule.id in route.matched_rule_ids
    assert route.endpoint.address == support_address
  end
end
