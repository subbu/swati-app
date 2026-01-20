defmodule Swati.Sessions.EventsTest do
  use ExUnit.Case, async: true

  alias Swati.Sessions.Events

  test "normalize adds category and idempotency key" do
    event = %{
      ts: "2026-01-19T17:42:07.813674Z",
      type: "tool.call",
      payload: %{name: "search", query: "status"}
    }

    normalized = Events.normalize(event)

    assert normalized["category"] == "tool"
    assert is_binary(normalized["idempotency_key"])
    assert normalized["idempotency_key"] != ""
  end

  test "idempotency key is deterministic" do
    event = %{
      ts: "2026-01-19T17:42:07.813674Z",
      type: "channel.message.received",
      payload: %{text: "hi", meta: %{b: 2, a: 1}}
    }

    key1 = Events.normalize(event)["idempotency_key"]
    key2 = Events.normalize(event)["idempotency_key"]

    assert key1 == key2
  end

  test "normalize keeps provided idempotency key" do
    event = %{
      ts: "2026-01-19T17:42:07.813674Z",
      type: "channel.message.received",
      idempotency_key: "evt-123",
      payload: %{}
    }

    assert Events.normalize(event)["idempotency_key"] == "evt-123"
  end
end
