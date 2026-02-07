defmodule SwatiWeb.TeamLive.SecurityTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  alias Swati.Accounts
  alias Swati.Accounts.Scope
  alias Swati.Repo

  test "role mutation events reject users without manage_roles", %{conn: conn} do
    owner_scope = owner_scope_fixture()
    admin_role_id = role_id_by_name!(owner_scope.tenant.id, "Admin")

    assert {:ok, member_manager_role} =
             Accounts.create_role(owner_scope.tenant.id, %{
               "name" => "Member Manager",
               "permissions" => ["manage_members"]
             })

    invited_email = unique_user_email()

    assert {:ok, membership} =
             Accounts.invite_member(
               owner_scope,
               %{"email" => invited_email, "role_id" => admin_role_id},
               & &1
             )

    assert {:ok, _updated_membership} =
             Accounts.update_member_role(owner_scope, membership.id, member_manager_role.id)

    member_manager = Accounts.get_user_by_email(invited_email)
    conn = log_in_user(conn, member_manager)

    {:ok, lv, _html} = live(conn, ~p"/settings/team")
    count_before = owner_scope.tenant.id |> Accounts.list_roles() |> length()

    render_hook(lv, "create_blank", %{})

    assert render(lv) =~ "Not authorized."

    count_after = owner_scope.tenant.id |> Accounts.list_roles() |> length()
    assert count_after == count_before
  end

  test "invalid template keys are handled without crashing", %{conn: conn} do
    owner = user_fixture()
    conn = log_in_user(conn, owner)

    {:ok, lv, _html} = live(conn, ~p"/settings/team?tab=roles")

    render_hook(lv, "create_from_template", %{"key" => "missing_template"})

    assert render(lv) =~ "Invalid template."
  end

  test "invite form requires explicit role selection", %{conn: conn} do
    owner = user_fixture()
    conn = log_in_user(conn, owner)

    {:ok, _lv, html} = live(conn, ~p"/settings/team")

    assert html =~ "Select a role"
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
