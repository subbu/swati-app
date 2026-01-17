defmodule SwatiWeb.CallsLive.IndexTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures

  alias Swati.Agents
  alias Swati.Calls
  alias Swati.Preferences

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, conn: log_in_user(conn, scope.user), scope: scope}
  end

  setup %{scope: scope} do
    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Parking assistant"}, scope.user)
    started_at = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, _call} =
      Calls.create_call_start(%{
        tenant_id: scope.tenant.id,
        agent_id: agent.id,
        provider: :plivo,
        provider_call_id: "call-#{System.unique_integer([:positive])}",
        from_number: "+15555550100",
        to_number: "+15555550200",
        status: :ended,
        started_at: started_at,
        duration_seconds: 186
      })

    :ok
  end

  test "persists column preferences across reloads", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/calls")

    assert has_element?(view, "#calls-table")
    assert has_element?(view, "th[data-column=\"duration_seconds\"]")

    render_change(view, "update_columns", %{
      "direction" => "true",
      "started_at" => "true",
      "from_number" => "true",
      "status" => "true",
      "agent_id" => "true"
    })

    refute has_element?(view, "th[data-column=\"duration_seconds\"]")

    assert Preferences.calls_index_state(scope)["columns"] == [
             "direction",
             "started_at",
             "from_number",
             "status",
             "agent_id"
           ]

    {:ok, view, _html} = live(conn, ~p"/calls")

    refute has_element?(view, "th[data-column=\"duration_seconds\"]")
    assert has_element?(view, "th[data-column=\"status\"]")
  end

  test "persists sort preferences", %{conn: conn, scope: scope} do
    {:ok, view, _html} = live(conn, ~p"/calls")

    render_click(view, "sort", %{"column" => "duration_seconds"})

    assert Preferences.calls_index_state(scope)["sort"] == %{
             "column" => "duration_seconds",
             "direction" => "desc"
           }

    {:ok, _view, _html} = live(conn, ~p"/calls")
  end
end
