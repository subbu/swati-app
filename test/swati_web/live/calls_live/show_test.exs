defmodule SwatiWeb.CallsLive.ShowTest do
  use SwatiWeb.ConnCase

  import Phoenix.LiveViewTest
  import Swati.AccountsFixtures
  alias Swati.Agents
  alias Swati.Calls

  setup %{conn: conn} do
    scope = user_scope_fixture()
    {:ok, conn: log_in_user(conn, scope.user), scope: scope}
  end

  setup %{scope: scope} do
    {:ok, agent} = Agents.create_agent(scope.tenant.id, %{name: "Parking assistant"}, scope.user)
    started_at = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, call} =
      Calls.create_call_start(%{
        tenant_id: scope.tenant.id,
        agent_id: agent.id,
        provider: :plivo,
        provider_call_id: "call-#{System.unique_integer([:positive])}",
        from_number: "+15555550100",
        to_number: "+15555550200",
        status: :ended,
        started_at: started_at,
        duration_seconds: 186,
        summary: "Caller asked about parking availability.",
        recording: %{stereo_url: "https://example.com/audio.opus"}
      })

    Calls.append_call_event(call.id, "transcript", started_at, %{
      tag: "AGENT",
      text: "Hello, how can I help?"
    })

    Calls.append_call_event(call.id, "transcript", DateTime.add(started_at, 5, :second), %{
      tag: "CALLER",
      text: "Looking for parking."
    })

    Calls.append_call_event(call.id, "tool_call", DateTime.add(started_at, 10, :second), %{
      id: "tool-1",
      name: "search",
      args: %{query: "Vijayanagar"}
    })

    Calls.append_call_event(call.id, "tool_result", DateTime.add(started_at, 12, :second), %{
      id: "tool-1",
      name: "search",
      isError: false,
      ms: 120,
      response: %{content: [%{text: "ok"}]}
    })

    Calls.append_call_event(
      call.id,
      "live_config_final",
      DateTime.add(started_at, 15, :second),
      %{
        model: "models/test",
        system_prompt: "You are a helpful assistant.",
        mcp: %{endpoint: "https://example.com"}
      }
    )

    {:ok, call: call}
  end

  test "renders call detail layout", %{conn: conn, call: call} do
    {:ok, view, _html} = live(conn, ~p"/calls/#{call.id}")

    assert has_element?(view, "#call-detail")
    assert has_element?(view, "#transcription-panel")

    # New audio UI (waveform + colocated hook binding)
    assert has_element?(view, "#call-audio-panel")
    assert has_element?(view, "#call-waveform-container")
    assert has_element?(view, "#call-waveform")

    assert has_element?(view, "#call-audio")
    assert has_element?(view, "#transcript-list")
  end
end
