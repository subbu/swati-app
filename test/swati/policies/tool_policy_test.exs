defmodule Swati.Policies.ToolPolicyTest do
  use ExUnit.Case, async: true

  alias Swati.Policies.ToolPolicy

  test "layer policies restrict allowlist and max calls" do
    base_config = %{"tool_policy" => %{"allow" => [], "deny" => [], "max_calls_per_turn" => 3}}
    channel_tools = ["tool_a", "tool_b", "tool_c"]

    policy =
      ToolPolicy.effective(
        base_config,
        [],
        [],
        channel_tools,
        [
          %{
            "tool_policy" => %{
              "allow" => ["tool_a"],
              "deny" => ["tool_b"],
              "max_calls_per_turn" => 1
            }
          }
        ]
      )

    assert policy["allow"] == ["tool_a"]
    assert policy["deny"] == ["tool_b"]
    assert policy["max_calls_per_turn"] == 1
  end
end
