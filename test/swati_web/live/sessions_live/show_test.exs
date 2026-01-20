defmodule SwatiWeb.SessionsLive.ShowTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures
  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Channels.Endpoint
  alias Swati.Repo
  alias Swati.Sessions

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, conn: log_in_user(conn, scope.user), scope: scope}
  end

  setup %{scope: scope} do
    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Parking assistant"}, scope.user)
    started_at = DateTime.utc_now()
    ended_at = DateTime.add(started_at, 186, :second)
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
      Sessions.create_session(scope.tenant.id, %{
        tenant_id: scope.tenant.id,
        agent_id: agent.id,
        channel_id: channel.id,
        endpoint_id: endpoint.id,
        status: :closed,
        started_at: started_at,
        ended_at: ended_at,
        metadata: %{
          from_address: "+15555550100",
          to_address: "+15555550200"
        }
      })

    :ok =
      Sessions.set_artifacts(session.id, %{
        recording: %{stereo_url: "https://example.com/audio.opus"}
      })

    :ok =
      Sessions.append_events(session.id, [
        %{
          type: "channel.transcript",
          ts: started_at,
          payload: %{tag: "AGENT", text: "Hello, how can I help?"}
        },
        %{
          type: "channel.transcript",
          ts: DateTime.add(started_at, 5, :second),
          payload: %{tag: "CUSTOMER", text: "Looking for parking."}
        },
        %{
          type: "tool.call",
          ts: DateTime.add(started_at, 10, :second),
          payload: %{id: "tool-1", name: "search", args: %{query: "Vijayanagar"}}
        },
        %{
          type: "tool.result",
          ts: DateTime.add(started_at, 12, :second),
          payload: %{
            id: "tool-1",
            name: "search",
            isError: false,
            ms: 120,
            response: %{content: [%{text: "ok"}]}
          }
        }
      ])

    {:ok, session: session}
  end

  test "renders session detail layout", %{conn: conn, session: session} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}")

    assert has_element?(view, "#call-detail")
    assert has_element?(view, "#transcription-panel")

    # New audio UI (waveform + colocated hook binding)
    assert has_element?(view, "#call-audio-panel")
    assert has_element?(view, "#call-waveform-container")
    assert has_element?(view, "#call-waveform")

    assert has_element?(view, "#call-audio")
    assert has_element?(view, "#transcript-list")
  end

  test "shows tool call invoke/result details", %{conn: conn, session: session} do
    {:ok, view, _html} = live(conn, ~p"/sessions/#{session.id}")

    assert has_element?(view, "#tool-invokes-tool-1")
    assert has_element?(view, "#tool-results-tool-1")
  end
end
