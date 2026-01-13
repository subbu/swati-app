defmodule SwatiWeb.AgentDataLive.IndexTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, conn: log_in_user(conn, scope.user), scope: scope}
  end

  test "new integration opens sheet", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/agent-data")

    refute has_element?(view, "#integration-form")

    view
    |> element("#new-integration-button")
    |> render_click()

    assert_patch(view, ~p"/integrations/new")
    assert has_element?(view, "#integration-form")
  end
end
