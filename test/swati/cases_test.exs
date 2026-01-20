defmodule Swati.CasesTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Cases

  test "create_case sets defaults and memory update" do
    scope = user_scope_fixture()

    {:ok, case_record} = Cases.create_case(scope.tenant.id, %{})

    assert case_record.status == :new
    assert case_record.priority == :normal

    events = [
      %{type: "channel.message.received", payload: %{text: "Need help with order"}},
      %{type: "channel.message.sent", payload: %{text: "Happy to help"}}
    ]

    {:ok, updated} = Cases.update_memory(case_record, events)

    assert is_map(updated.memory)
    assert updated.memory["summary"] =~ "Need help"
  end
end
