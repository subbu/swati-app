defmodule SwatiWeb.SurfacesLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "surfaces index renders controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/surfaces")

    assert has_element?(view, "#surfaces-index")
    assert has_element?(view, "#agent-assignment-modal")
  end
end
