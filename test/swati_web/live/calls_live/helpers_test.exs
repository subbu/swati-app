defmodule SwatiWeb.CallsLive.HelpersTest do
  use ExUnit.Case, async: true

  alias SwatiWeb.CallsLive.Helpers

  test "call_duration_seconds prefers explicit duration_seconds" do
    assert Helpers.call_duration_seconds(%{duration_seconds: 125}) == 125
  end

  test "call_duration_seconds computes diff from started_at and ended_at" do
    started_at = ~U[2024-01-01 00:00:00Z]
    ended_at = DateTime.add(started_at, 95, :second)

    assert Helpers.call_duration_seconds(%{started_at: started_at, ended_at: ended_at}) == 95
  end

  test "call_duration_seconds computes live duration for in-progress calls" do
    started_at = DateTime.utc_now()
    duration = Helpers.call_duration_seconds(%{started_at: started_at, status: :in_progress})

    assert is_integer(duration)
    assert duration >= 0
  end
end
