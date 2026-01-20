defmodule SwatiWeb.SessionsLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions

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
end
