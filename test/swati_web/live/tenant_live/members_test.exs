defmodule SwatiWeb.TenantLive.MembersTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  alias Swati.Accounts
  alias Swati.Repo

  describe "members page" do
    setup %{conn: conn} do
      owner = user_fixture()
      owner = Repo.preload(owner, [:membership, :tenant])
      %{conn: log_in_user(conn, owner), owner: owner}
    end

    test "renders members list and invite form", %{conn: conn, owner: owner} do
      {:ok, _lv, html} = live(conn, ~p"/settings/members")

      assert html =~ "Invite a teammate"
      assert html =~ "Current members"
      assert html =~ owner.email
    end

    test "invites a new member", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/settings/members")

      email = unique_user_email()

      lv
      |> form("#invite-member-form", membership_invite: %{email: email, role: "member"})
      |> render_submit()

      assert Accounts.get_user_by_email(email)
    end
  end

  test "redirects members without manage access", %{conn: conn} do
    owner_scope = user_scope_fixture()
    email = unique_user_email()

    {:ok, _membership} =
      Accounts.invite_member(owner_scope, %{"email" => email, "role" => "member"}, & &1)

    member = Accounts.get_user_by_email(email)
    conn = log_in_user(conn, member)

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/settings/members")
  end
end
