defmodule SwatiWeb.SessionsLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Customers.Customer
  alias Swati.Repo
  alias Swati.Sessions
  alias SwatiWeb.Formatting

  setup :register_and_log_in_user

  test "sessions index renders table", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, _session} =
      Sessions.create_session(scope.tenant.id, %{channel_id: channel.id, endpoint_id: endpoint.id})

    {:ok, view, _html} = live(conn, ~p"/sessions")

    assert has_element?(view, "#sessions-table")
    assert has_element?(view, "#sessions-filter")
    assert has_element?(view, "#sessions-table thead input[name='select-all']")
    assert has_element?(view, "#sessions-table tbody input[name^='select-session-']")
    assert has_element?(view, "[data-selected-actions]", "Actions")
    refute has_element?(view, "th[data-column='session']")
    assert has_element?(view, "th[data-column='duration']")
  end

  test "sessions index formats phone number for customer", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "+918884938830"
      })
      |> Repo.insert()

    {:ok, customer} =
      %Customer{}
      |> Customer.changeset(%{
        tenant_id: scope.tenant.id,
        primary_phone: "+918884938830"
      })
      |> Repo.insert()

    {:ok, _session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        customer_id: customer.id,
        metadata: %{"from_address" => "+918884938830"}
      })

    {:ok, view, _html} = live(conn, ~p"/sessions")
    html = render(view)

    assert html =~ (Formatting.phone("+918884938830", scope.tenant) || "+918884938830")
  end

  test "toggling columns keeps header and rows aligned", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "+918884938830"
      })
      |> Repo.insert()

    {:ok, customer} =
      %Customer{}
      |> Customer.changeset(%{
        tenant_id: scope.tenant.id,
        name: "Toggle Test Customer"
      })
      |> Repo.insert()

    {:ok, _session} =
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        customer_id: customer.id,
        external_id: "call-toggle-123",
        metadata: %{"from_address" => "+918884938830"}
      })

    {:ok, view, _html} = live(conn, ~p"/sessions")

    refute has_element?(view, "th[data-column='session']")
    refute has_element?(view, "a", "call-toggle-123")

    _ =
      render_change(view, "update_columns", %{
        "session" => "true",
        "customer" => "true",
        "channel" => "true",
        "direction" => "true",
        "status" => "true",
        "duration" => "true",
        "last_event_at" => "true",
        "agent" => "true"
      })

    assert has_element?(view, "th[data-column='session']")
    assert has_element?(view, "a", "call-toggle-123")

    _ =
      render_change(view, "update_columns", %{
        "customer" => "true",
        "channel" => "true",
        "direction" => "true",
        "status" => "true",
        "duration" => "true",
        "last_event_at" => "true",
        "agent" => "true"
      })

    refute has_element?(view, "th[data-column='session']")
    refute has_element?(view, "a", "call-toggle-123")
    assert has_element?(view, "td", "Toggle Test Customer")
  end

  test "session show renders detail", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{channel_id: channel.id, endpoint_id: endpoint.id})

    {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}")

    assert has_element?(view, "#call-detail")
  end

  test "bulk summarize uses selected sessions", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{channel_id: channel.id, endpoint_id: endpoint.id})

    {:ok, view, _html} = live(conn, ~p"/sessions")

    _ = render_hook(view, "selected_sessions_changed", %{"session_ids" => [session.id]})
    _ = render_click(view, "bulk_action", %{"action" => "summarize_selected"})

    assert has_element?(view, "[data-selected-actions]", "sessions selected")
  end

  test "ai recommendations start loading after selection event", %{conn: conn, scope: scope} do
    {:ok, channel} = Channels.ensure_voice_channel(scope.tenant.id)

    {:ok, endpoint} =
      %Endpoint{}
      |> Endpoint.changeset(%{
        tenant_id: scope.tenant.id,
        channel_id: channel.id,
        address: "endpoint-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    {:ok, session} =
      Sessions.create_session(scope.tenant.id, %{channel_id: channel.id, endpoint_id: endpoint.id})

    {:ok, view, _html} = live(conn, ~p"/sessions")

    _ = render_hook(view, "selected_sessions_changed", %{"session_ids" => [session.id]})

    assert has_element?(view, "[data-selected-actions]", "Generating AI recommendations")
  end
end
