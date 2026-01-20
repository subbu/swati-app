defmodule SwatiWeb.CasesLiveTest do
  use SwatiWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Swati.Cases
  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions

  setup :register_and_log_in_user

  test "cases index renders table", %{conn: conn, scope: scope} do
    {:ok, _case} = Cases.create_case(scope.tenant.id, %{})

    {:ok, view, _html} = live(conn, ~p"/cases")

    assert has_element?(view, "#cases-table")
    assert has_element?(view, "#cases-filter")
  end

  test "case show renders sessions table", %{conn: conn, scope: scope} do
    {:ok, case_record} = Cases.create_case(scope.tenant.id, %{title: "Billing issue"})
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
      Sessions.create_session(scope.tenant.id, %{
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        case_id: case_record.id
      })

    {:ok, view, _html} = live(conn, ~p"/cases/#{case_record.id}")

    assert has_element?(view, "#case-sessions-table")
  end
end
