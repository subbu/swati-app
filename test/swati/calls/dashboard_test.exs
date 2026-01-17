defmodule Swati.Calls.DashboardTest do
  use ExUnit.Case, async: true

  alias Swati.Calls.Call
  alias Swati.Calls.Dashboard

  test "timeline chart uses longest hourly duration for max_hours" do
    calls = [
      %Call{duration_seconds: 2880, started_at: ~U[2025-01-01 09:00:00Z]},
      %Call{duration_seconds: 3600, started_at: ~U[2025-01-01 10:00:00Z]},
      %Call{duration_seconds: 3600, started_at: ~U[2025-01-01 11:00:00Z]},
      %Call{duration_seconds: 4320, started_at: ~U[2025-01-01 12:00:00Z]},
      %Call{duration_seconds: 14_400, started_at: ~U[2025-01-01 13:00:00Z]}
    ]

    chart = Dashboard.calculate_timeline_chart(calls, ~D[2025-01-01])

    assert chart.max_hours == 4.0
    assert hd(chart.y_labels) == "4h 0m"
  end

  test "timeline chart uses sub-hour max when longest call is under an hour" do
    calls = [
      %Call{duration_seconds: 600, started_at: ~U[2025-01-02 09:00:00Z]},
      %Call{duration_seconds: 900, started_at: ~U[2025-01-02 10:00:00Z]},
      %Call{duration_seconds: 1200, started_at: ~U[2025-01-02 11:00:00Z]}
    ]

    chart = Dashboard.calculate_timeline_chart(calls, ~D[2025-01-02])

    assert chart.max_hours == 0.5
    assert hd(chart.y_labels) == "30m"
  end
end
