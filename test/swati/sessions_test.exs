defmodule Swati.SessionsTest do
  use Swati.DataCase, async: true

  import Swati.AccountsFixtures

  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions

  test "append_events stores events and updates session state" do
    scope = user_scope_fixture()
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

    ts = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    :ok =
      Sessions.append_events(session.id, [
        %{ts: ts, type: "channel.message.received", payload: %{text: "hi"}}
      ])

    events = Sessions.list_session_events(session.id)
    assert length(events) == 1

    session = Sessions.get_session!(scope.tenant.id, session.id)
    assert session.status == :active
    assert session.last_event_at == ts
  end
end
