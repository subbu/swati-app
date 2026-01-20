defmodule Swati.Cases.LinkingTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Cases
  alias Swati.Cases.Linking
  alias Swati.Customers

  test "pick_case reuses an open case within window" do
    scope = user_scope_fixture()
    {:ok, customer} = Customers.create_customer(scope.tenant.id, %{name: "Acme"})

    {:ok, case_record} =
      Cases.create_case(scope.tenant.id, %{customer_id: customer.id, category: "billing"})

    policy = %{"case_linking" => %{"window_hours" => 24, "min_confidence" => 0.5}}

    assert {:reuse, ^case_record, info} =
             Linking.pick_case(scope.tenant.id, customer.id, "billing", [policy])

    assert info["within_window"] == true
    assert info["matched_category"] == true
  end

  test "pick_case respects required category" do
    scope = user_scope_fixture()
    {:ok, customer} = Customers.create_customer(scope.tenant.id, %{name: "Acme"})

    {:ok, _case_record} =
      Cases.create_case(scope.tenant.id, %{customer_id: customer.id, category: "billing"})

    policy = %{"case_linking" => %{"require_category" => true, "min_confidence" => 0.1}}

    assert Linking.pick_case(scope.tenant.id, customer.id, "shipping", [policy]) == nil
  end
end
