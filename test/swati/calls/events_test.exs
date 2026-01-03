defmodule Swati.Calls.EventsTest do
  use ExUnit.Case, async: true

  alias Swati.Calls.Events

  test "normalize accepts atom and string keys" do
    event = Events.normalize(%{ts: "2026-01-01T10:00:00.000000Z", type: "start", payload: %{}})

    assert %{"type" => "start", "payload" => %{}} = event
    assert %DateTime{} = event["ts"]
  end

  test "normalize defaults invalid timestamps to utc_now" do
    event = Events.normalize(%{"ts" => "bogus", "type" => "start", "payload" => %{}})
    assert %DateTime{} = event["ts"]
  end

  test "parse_datetime truncates to microseconds" do
    dt = Events.parse_datetime("2026-01-01T10:00:00.123456Z")
    assert {123_456, 6} = dt.microsecond
  end
end
