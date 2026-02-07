defmodule Swati.Tenancy.MembershipsSecurityTest do
  use Swati.DataCase

  import Swati.AccountsFixtures

  alias Swati.Accounts
  alias Swati.Accounts.Scope
  alias Swati.Repo

  test "invite_member/3 rejects role ids from another tenant" do
    owner_scope = owner_scope_fixture()
    other_scope = owner_scope_fixture()

    foreign_role_id = role_id_by_name!(other_scope.tenant.id, "Admin")

    assert {:error, changeset} =
             Accounts.invite_member(
               owner_scope,
               %{"email" => unique_user_email(), "role_id" => foreign_role_id},
               & &1
             )

    assert "is invalid" in errors_on(changeset).role_id
  end

  test "update_member_role/3 rejects role ids from another tenant" do
    owner_scope = owner_scope_fixture()
    other_scope = owner_scope_fixture()

    admin_role_id = role_id_by_name!(owner_scope.tenant.id, "Admin")

    assert {:ok, membership} =
             Accounts.invite_member(
               owner_scope,
               %{"email" => unique_user_email(), "role_id" => admin_role_id},
               & &1
             )

    foreign_role_id = role_id_by_name!(other_scope.tenant.id, "Admin")

    assert {:error, :invalid_role} =
             Accounts.update_member_role(owner_scope, membership.id, foreign_role_id)
  end

  defp owner_scope_fixture do
    user =
      user_fixture()
      |> Repo.preload([:tenant, membership: :role])

    Scope.for_user(user)
  end

  defp role_id_by_name!(tenant_id, name) do
    tenant_id
    |> Accounts.list_roles()
    |> Enum.find(&(&1.name == name))
    |> case do
      nil -> raise "expected role #{name} for tenant #{tenant_id}"
      role -> role.id
    end
  end
end
