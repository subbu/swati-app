defmodule SwatiWeb.ChannelsLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "channels index renders tables", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/channels")

    assert has_element?(view, "#channels-table")
    assert has_element?(view, "#endpoints-table")
    assert has_element?(view, "#connection-providers")
    assert has_element?(view, "#provider-gmail")
    assert has_element?(view, "[phx-value-preset=\"zoho\"]")
    assert has_element?(view, "[phx-value-preset=\"custom\"]")
    assert has_element?(view, "#channel-connections-table")
  end
end
