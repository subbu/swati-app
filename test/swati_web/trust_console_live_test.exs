defmodule SwatiWeb.TrustConsoleLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "trust console timeline renders", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trust")

    assert has_element?(view, "#trust-console")
    assert has_element?(view, "#trust-case-list")
    assert has_element?(view, "#trust-case-timeline")
  end

  test "trust policy view renders", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trust/policy")

    assert has_element?(view, "#trust-policy")
    assert has_element?(view, "#trust-policy-tools")
  end

  test "trust reliability view renders", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trust/reliability")

    assert has_element?(view, "#trust-reliability")
    assert has_element?(view, "#trust-reliability-tools")
  end
end
