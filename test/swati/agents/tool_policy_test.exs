defmodule Swati.Agents.ToolPolicyTest do
  use ExUnit.Case, async: true

  alias Swati.Agents.ToolPolicy
  alias Swati.Integrations.Integration
  alias Swati.Webhooks.Webhook

  test "normalize fills defaults and coerces types" do
    assert %{
             "allow" => [],
             "deny" => [],
             "max_calls_per_turn" => 3
           } == ToolPolicy.normalize(%{})
  end

  test "normalize handles explicit values" do
    policy =
      ToolPolicy.normalize(%{
        "allow" => ["a"],
        "deny" => ["b"],
        "max_calls_per_turn" => 5
      })

    assert policy["allow"] == ["a"]
    assert policy["deny"] == ["b"]
    assert policy["max_calls_per_turn"] == 5
  end

  test "effective policy intersects allowlists and applies deny list" do
    base_config = %{
      "tool_policy" => %{
        "allow" => ["search", "create"],
        "deny" => ["create"],
        "max_calls_per_turn" => 5
      }
    }

    integration = %Integration{allowed_tools: ["search", "create", "other"]}

    policy = ToolPolicy.effective(base_config, [{integration, nil}], [])

    assert policy["allow"] == ["search"]
    assert policy["deny"] == ["create"]
    assert policy["max_calls_per_turn"] == 5
  end

  test "effective policy uses base allowlist when integrations empty" do
    base_config = %{"tool_policy" => %{"allow" => ["search"], "deny" => []}}

    policy = ToolPolicy.effective(base_config, [], [])

    assert policy["allow"] == ["search"]
    assert policy["deny"] == []
    assert policy["max_calls_per_turn"] == 3
  end

  test "effective policy defaults to integration allowlist with prefix" do
    base_config = %{"tool_policy" => %{"allow" => [], "deny" => []}}
    integration = %Integration{allowed_tools: ["lookup"], tool_prefix: "crm"}

    policy = ToolPolicy.effective(base_config, [{integration, nil}], [])

    assert policy["allow"] == ["crm/lookup"]
    assert policy["deny"] == []
    assert policy["max_calls_per_turn"] == 3
  end

  test "effective policy unions integrations and webhooks" do
    base_config = %{"tool_policy" => %{"allow" => [], "deny" => []}}
    integration = %Integration{allowed_tools: ["search"]}
    webhook = %Webhook{tool_name: "create_ticket"}

    policy = ToolPolicy.effective(base_config, [{integration, nil}], [{webhook, nil}])

    assert Enum.sort(policy["allow"]) == ["create_ticket", "search"]
    assert policy["deny"] == []
    assert policy["max_calls_per_turn"] == 3
  end
end
