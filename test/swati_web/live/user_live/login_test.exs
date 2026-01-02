defmodule SwatiWeb.UserLive.LoginTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  describe "login page" do
    test "renders login page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(lv, "h1", "Welcome back")
      assert has_element?(lv, "button", "Send magic link")
      assert has_element?(lv, "button", "Sign in")
    end
  end

  describe "user login - magic link" do
    test "sends magic link email when user exists", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"

      assert Swati.Repo.get_by!(Swati.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not disclose if user is registered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        form(lv, "#login_form_magic", user: %{email: "idonotexist@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end
  end

  describe "user login - password" do
    test "redirects if user logs in with valid credentials", %{conn: conn} do
      user = user_fixture() |> set_password()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password",
          user: %{email: user.email, password: valid_user_password(), remember_me: true}
        )

      conn = submit_form(form, conn)

      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to login page with a flash error if credentials are invalid", %{
      conn: conn
    } do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      form =
        form(lv, "#login_form_password", user: %{email: "test@email.com", password: "123456"})

      render_submit(form, %{user: %{remember_me: true}})

      conn = follow_trigger_action(form, conn)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end

  describe "login navigation" do
    test "does not show sign up links", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      refute has_element?(lv, "a", "Sign up")
      refute has_element?(lv, "a", "Register")
    end
  end

  describe "re-authentication (sudo mode)" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "shows login page with email filled in", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(
               lv,
               "p",
               "Reauthenticate to continue managing your account."
             )

      refute has_element?(lv, "a", "Register")
      assert has_element?(lv, "button", "Send magic link")
      assert has_element?(lv, ~s(#login_form_magic_email[value="#{user.email}"]))
    end
  end
end
