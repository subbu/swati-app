defmodule Swati.Webhooks.ManagementTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Agents.Agent
  alias Swati.Webhooks

  setup do
    scope = user_scope_fixture()
    {:ok, scope: scope}
  end

  test "create webhook normalizes tool_name and payload", %{scope: scope} do
    attrs = %{
      "name" => "Create Ticket",
      "endpoint_url" => "https://example.com/tickets",
      "sample_payload" => "subject: Hello\npriority: 2"
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)
    assert webhook.tool_name == "create-ticket"
    assert webhook.sample_payload["subject"] == "Hello"
    assert webhook.sample_payload["priority"] == 2
  end

  test "create webhook requires auth token for bearer", %{scope: scope} do
    attrs = %{
      "name" => "Secure",
      "endpoint_url" => "https://example.com/secure",
      "auth_type" => :bearer
    }

    assert {:error, "auth_token_required"} =
             Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)
  end

  test "create webhook stores tags", %{scope: scope} do
    assert {:ok, tag} =
             Webhooks.create_tag(
               scope.tenant.id,
               %{"name" => "Customer", "color" => "#0F766E"},
               scope.user
             )

    attrs = %{
      "name" => "Notify",
      "endpoint_url" => "https://example.com/notify",
      "tag_ids" => [tag.id]
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)
    assert Enum.map(webhook.tags, & &1.id) == [tag.id]
  end

  test "update webhook replaces tags", %{scope: scope} do
    assert {:ok, first_tag} =
             Webhooks.create_tag(
               scope.tenant.id,
               %{"name" => "Billing", "color" => "#2563EB"},
               scope.user
             )

    assert {:ok, second_tag} =
             Webhooks.create_tag(
               scope.tenant.id,
               %{"name" => "Support", "color" => "#16A34A"},
               scope.user
             )

    attrs = %{
      "name" => "Notify",
      "endpoint_url" => "https://example.com/notify",
      "tag_ids" => [first_tag.id]
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)

    assert {:ok, updated} =
             Webhooks.update_webhook(webhook, %{"tag_ids" => [second_tag.id]}, scope.user)

    assert Enum.map(updated.tags, & &1.id) == [second_tag.id]
  end

  test "update webhook blocks tool_name change when attached", %{scope: scope} do
    attrs = %{
      "name" => "Lookup",
      "endpoint_url" => "https://example.com/lookup",
      "sample_payload" => "query: hi"
    }

    assert {:ok, webhook} = Webhooks.create_webhook(scope.tenant.id, attrs, scope.user)

    agent_attrs = %{
      name: "Agent",
      status: "draft",
      language: "en-IN",
      voice_provider: "google",
      voice_name: "Fenrir",
      llm_provider: "google",
      llm_model: Agent.default_llm_model(),
      instructions: Agent.default_instructions(),
      tool_policy: Agent.default_tool_policy()
    }

    assert {:ok, agent} = Agents.create_agent(scope.tenant.id, agent_attrs, scope.user)
    assert {:ok, _} = Agents.upsert_agent_webhook(agent.id, webhook.id, true)

    assert {:error, "tool_name_locked"} =
             Webhooks.update_webhook(webhook, %{"tool_name" => "lookup-v2"}, scope.user)
  end
end
