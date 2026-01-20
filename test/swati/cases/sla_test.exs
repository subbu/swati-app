defmodule Swati.Cases.SlaTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Cases
  alias Swati.Customers
  alias Swati.Repo
  alias Swati.Tenancy.Tenant

  test "create_case assigns sla_due_at based on tenant policy" do
    scope = user_scope_fixture()
    tenant = Repo.get!(Tenant, scope.tenant.id)

    {:ok, _tenant} =
      tenant
      |> Tenant.changeset(%{
        policy: %{
          "case_sla" => %{"priorities" => %{"urgent" => 1}}
        }
      })
      |> Repo.update()

    tenant = Repo.get!(Tenant, scope.tenant.id)
    assert get_in(tenant.policy, ["case_sla", "priorities", "urgent"]) == 1

    {:ok, customer} = Customers.create_customer(scope.tenant.id, %{name: "Acme"})

    {:ok, case_record} =
      Cases.create_case(scope.tenant.id, %{
        customer_id: customer.id,
        priority: :urgent
      })

    assert case_record.sla_due_at

    diff = DateTime.diff(case_record.sla_due_at, case_record.opened_at, :second)
    assert diff == 3600
  end
end
