defmodule Swati.RuntimeTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Repo
  alias Swati.Runtime
  alias Swati.Telephony.PhoneNumber

  defp unique_phone do
    "+1555#{System.unique_integer([:positive])}"
  end

  test "resolve_runtime builds session and policy" do
    scope = user_scope_fixture()

    {:ok, agent} =
      Agents.create_agent(scope.tenant.id, %{name: "Front Desk"}, scope.user)

    {:ok, agent, _version} = Agents.publish_agent(agent, scope.user)

    {:ok, phone_number} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: unique_phone(),
        country: "US",
        status: :provisioned,
        inbound_agent_id: agent.id
      })
      |> Repo.insert()

    {:ok, _endpoint} = Channels.ensure_endpoint_for_phone_number(phone_number)

    {:ok, payload} =
      Runtime.resolve_runtime(%{
        channel_key: "voice",
        endpoint_address: phone_number.e164,
        from_address: "+15550001111",
        session_external_id: "call-123"
      })

    assert payload.channel.key == "voice"
    assert payload.endpoint.address == phone_number.e164
    assert payload.session.external_id == "call-123"
    assert payload.agent.id == agent.id
    assert "channel.message.send" in payload.agent.tool_policy["allow"]
    assert payload.case_linking["strategy"] == "new_case"
    assert payload.config_version == 5
    assert payload.policy.tool_policy["allow"] == payload.agent.tool_policy["allow"]
    assert payload.agent.system_prompt =~ "# Swati Voice Agent System Prompt"
    assert payload.agent.system_prompt =~ "## Customer"
    assert payload.agent.system_prompt =~ "+15550001111"
  end
end
