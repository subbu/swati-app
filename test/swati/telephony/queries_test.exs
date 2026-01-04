defmodule Swati.Telephony.QueriesTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Telephony.PhoneNumber
  alias Swati.Telephony.Queries

  setup do
    scope = user_scope_fixture()

    {:ok, active} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: "+15555550001",
        country: "US",
        status: :active
      })
      |> Repo.insert()

    {:ok, suspended} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: "+15555550002",
        country: "US",
        status: :suspended
      })
      |> Repo.insert()

    {:ok, scope: scope, active: active, suspended: suspended}
  end

  test "list_phone_numbers accepts atom filter keys", %{scope: scope, active: active} do
    results = Queries.list_phone_numbers(scope.tenant.id, %{status: "active"})
    assert Enum.map(results, & &1.id) == [active.id]
  end

  test "list_phone_numbers ignores blank filter values", %{scope: scope} do
    results = Queries.list_phone_numbers(scope.tenant.id, %{"status" => ""})
    assert length(results) == 2
  end

  test "get_phone_number_by_e164! normalizes input", %{scope: scope} do
    {:ok, phone_number} =
      %PhoneNumber{}
      |> PhoneNumber.changeset(%{
        tenant_id: scope.tenant.id,
        provider: :plivo,
        e164: "918035739111",
        country: "IN",
        status: :active
      })
      |> Repo.insert()

    result = Queries.get_phone_number_by_e164!("+91 80357-39111")
    assert result.id == phone_number.id
  end
end
