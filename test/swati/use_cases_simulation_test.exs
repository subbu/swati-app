defmodule Swati.UseCasesSimulationTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Cases
  alias Swati.Sessions
  alias Swati.UseCases.Simulator

  test "simulator seeds use cases" do
    scope = user_scope_fixture()

    results = Simulator.run(scope.tenant.id)

    assert %{use_case_a: case_id} = results
    assert Cases.get_case!(scope.tenant.id, case_id)
    assert length(Cases.list_cases(scope.tenant.id)) >= 6
    assert length(Sessions.list_sessions(scope.tenant.id)) >= 6
  end
end
