defmodule Swati.Calls.Dashboard do
  @moduledoc """
  Dashboard analytics and aggregation functions for calls data.
  """

  import Ecto.Query, warn: false

  alias Swati.Repo
  alias Swati.Tenancy
  alias Swati.Calls.Call
  alias Swati.Agents.Agent

  @doc """
  Get all dashboard statistics for a tenant within a date range.
  Returns a map with all KPIs and chart data.
  """
  def get_dashboard_stats(tenant_id, opts \\ []) do
    start_date = Keyword.get(opts, :start_date, default_start_date())
    end_date = Keyword.get(opts, :end_date, DateTime.utc_now())
    agent_id = Keyword.get(opts, :agent_id)

    calls = list_calls_in_range(tenant_id, start_date, end_date, agent_id)

    timeline_date = Keyword.get(opts, :timeline_date)

    %{
      kpis: calculate_kpis(calls),
      status_breakdown: calculate_status_breakdown(calls),
      calls_trend: calculate_calls_trend(calls, start_date, end_date),
      peak_hours_matrix: calculate_peak_hours_matrix(calls),
      popular_times: calculate_popular_times(calls),
      timeline_chart: calculate_timeline_chart(calls, timeline_date),
      timeline_dates: calculate_timeline_dates(calls),
      duration_buckets: calculate_duration_buckets(calls),
      top_from_numbers: calculate_top_numbers(calls, :from_number),
      top_to_numbers: calculate_top_numbers(calls, :to_number),
      coverage: calculate_coverage(calls),
      outliers: calculate_outliers(calls),
      agent_leaderboard: calculate_agent_leaderboard(tenant_id, calls)
    }
  end

  def get_timeline_data(tenant_id, opts \\ []) do
    start_date = Keyword.get(opts, :start_date, default_start_date())
    end_date = Keyword.get(opts, :end_date, DateTime.utc_now())
    agent_id = Keyword.get(opts, :agent_id)
    timeline_date = Keyword.get(opts, :timeline_date)

    calls = list_calls_in_range(tenant_id, start_date, end_date, agent_id)

    %{
      timeline_chart: calculate_timeline_chart(calls, timeline_date),
      timeline_dates: calculate_timeline_dates(calls)
    }
  end

  defp default_start_date do
    DateTime.utc_now()
    |> DateTime.add(-30, :day)
    |> DateTime.truncate(:second)
  end

  defp list_calls_in_range(tenant_id, start_date, end_date, agent_id) do
    Call
    |> Tenancy.scope(tenant_id)
    |> where([c], c.started_at >= ^start_date and c.started_at <= ^end_date)
    |> maybe_filter_agent(agent_id)
    |> Repo.all()
  end

  defp maybe_filter_agent(query, nil), do: query
  defp maybe_filter_agent(query, ""), do: query

  defp maybe_filter_agent(query, agent_id) do
    from(c in query, where: c.agent_id == ^agent_id)
  end

  @doc """
  Calculate KPI metrics.
  """
  def calculate_kpis(calls) do
    total = length(calls)
    ended_count = Enum.count(calls, &(&1.status == :ended))
    failed_count = Enum.count(calls, &(&1.status in [:failed, :error]))

    durations =
      calls
      |> Enum.filter(&(&1.duration_seconds && &1.duration_seconds > 0))
      |> Enum.map(& &1.duration_seconds)

    avg_duration =
      if length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0.0

    median_duration = calculate_median(durations)
    total_talk_time = Enum.sum(durations)

    completion_rate = if total > 0, do: ended_count / total * 100, else: 0.0
    failure_rate = if total > 0, do: failed_count / total * 100, else: 0.0

    %{
      total_calls: total,
      completed_calls: ended_count,
      completion_rate: Float.round(completion_rate * 1.0, 1),
      failure_rate: Float.round(failure_rate * 1.0, 1),
      avg_duration: Float.round(avg_duration * 1.0, 0),
      median_duration: median_duration,
      total_talk_time: total_talk_time,
      # Sparkline data: calls per day for last 7 days
      trend_sparkline: calculate_daily_trend(calls, 7)
    }
  end

  defp calculate_median(list, precision \\ 0)
  defp calculate_median([], _precision), do: 0.0

  defp calculate_median(list, precision) do
    sorted = Enum.sort(list)
    len = length(sorted)
    mid = div(len, 2)

    result =
      if rem(len, 2) == 0 do
        (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
      else
        Enum.at(sorted, mid) * 1.0
      end

    Float.round(result, precision)
  end

  defp calculate_daily_trend(calls, days) do
    now = DateTime.utc_now()

    (days - 1)..0
    |> Enum.map(fn offset ->
      date = DateTime.add(now, -offset, :day) |> DateTime.to_date()

      Enum.count(calls, fn call ->
        call.started_at && DateTime.to_date(call.started_at) == date
      end)
    end)
  end

  @doc """
  Calculate status breakdown for funnel chart.
  """
  def calculate_status_breakdown(calls) do
    statuses = [:started, :in_progress, :ended, :failed, :cancelled, :error]

    counts =
      Enum.reduce(statuses, %{}, fn status, acc ->
        count = Enum.count(calls, &(&1.status == status))
        Map.put(acc, status, count)
      end)

    labels =
      statuses
      |> Enum.map(&status_label/1)

    values = Enum.map(statuses, &Map.get(counts, &1, 0))

    %{
      labels: labels,
      values: values,
      statuses: Enum.map(statuses, &Atom.to_string/1),
      counts: counts
    }
  end

  defp status_label(:started), do: "Started"
  defp status_label(:in_progress), do: "In Progress"
  defp status_label(:ended), do: "Ended"
  defp status_label(:failed), do: "Failed"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(:error), do: "Error"
  defp status_label(status), do: to_string(status)

  @doc """
  Calculate calls trend by day with status breakdown.
  """
  def calculate_calls_trend(calls, start_date, end_date) do
    days = Date.range(DateTime.to_date(start_date), DateTime.to_date(end_date))

    # Group calls by date and status
    grouped =
      Enum.reduce(calls, %{}, fn call, acc ->
        if call.started_at do
          date = DateTime.to_date(call.started_at)
          status = call.status || :unknown

          acc
          |> Map.update(date, %{status => 1}, fn date_counts ->
            Map.update(date_counts, status, 1, &(&1 + 1))
          end)
        else
          acc
        end
      end)

    labels = days |> Enum.map(&Calendar.strftime(&1, "%b %d"))

    # Create dataset for each status
    statuses = [:ended, :in_progress, :failed, :cancelled, :error]

    datasets =
      Enum.map(statuses, fn status ->
        data =
          Enum.map(days, fn date ->
            get_in(grouped, [date, status]) || 0
          end)

        %{
          label: status_label(status),
          data: data,
          status: Atom.to_string(status)
        }
      end)

    %{labels: labels, datasets: datasets}
  end

  @doc """
  Calculate peak hours heatmap matrix (7 days x 24 hours).
  """
  def calculate_peak_hours_matrix(calls) do
    # Initialize 7x24 matrix (days of week x hours)
    matrix = List.duplicate(List.duplicate(0, 24), 7)

    matrix =
      Enum.reduce(calls, matrix, fn call, acc ->
        if call.started_at do
          # Get day of week (0 = Sunday in Elixir's :calendar)
          day_of_week = Date.day_of_week(DateTime.to_date(call.started_at), :sunday) - 1
          hour = call.started_at.hour

          List.update_at(acc, day_of_week, fn row ->
            List.update_at(row, hour, &(&1 + 1))
          end)
        else
          acc
        end
      end)

    %{matrix: matrix}
  end

  @doc """
  Calculate popular times (Google Maps style) - average calls by hour.
  """
  def calculate_popular_times(calls) do
    # Count calls per hour across all days
    hour_counts =
      Enum.reduce(calls, %{}, fn call, acc ->
        if call.started_at do
          hour = call.started_at.hour
          Map.update(acc, hour, 1, &(&1 + 1))
        else
          acc
        end
      end)

    # Calculate unique days to get averages
    unique_days =
      calls
      |> Enum.filter(& &1.started_at)
      |> Enum.map(&DateTime.to_date(&1.started_at))
      |> Enum.uniq()
      |> length()
      |> max(1)

    labels = Enum.map(0..23, &to_string/1)

    values =
      Enum.map(0..23, fn hour ->
        count = Map.get(hour_counts, hour, 0)
        Float.round(count / unique_days, 1)
      end)

    %{labels: labels, values: values}
  end

  @doc """
  Calculate timeline chart data (avg talk time by hour).
  """
  def calculate_timeline_chart(calls, timeline_date \\ nil) do
    hours = Enum.to_list(7..22)

    calls = filter_calls_for_date(calls, timeline_date)

    totals_by_hour =
      Enum.reduce(calls, %{}, fn call, acc ->
        duration = call.duration_seconds || 0

        if call.started_at && duration > 0 do
          hour = call.started_at.hour

          if hour in hours do
            Map.update(acc, hour, duration, &(&1 + duration))
          else
            acc
          end
        else
          acc
        end
      end)

    unique_days =
      if timeline_date do
        1
      else
        calls
        |> Enum.filter(& &1.started_at)
        |> Enum.map(&DateTime.to_date(&1.started_at))
        |> Enum.uniq()
        |> length()
        |> max(1)
      end

    totals =
      Enum.map(hours, fn hour ->
        Map.get(totals_by_hour, hour, 0) / unique_days
      end)

    trend_totals = moving_average(totals, 3)

    values = Enum.map(totals, &Float.round(&1 / 3600, 2))
    trend_values = Enum.map(trend_totals, &Float.round(&1 / 3600, 2))

    max_hours = compute_max_hours(values, trend_values)

    %{
      labels: Enum.map(hours, &format_hour_label/1),
      values: values,
      trend_values: trend_values,
      totals: totals,
      trend_totals: trend_totals,
      y_labels: build_y_labels(max_hours),
      max_hours: Float.round(max_hours, 2)
    }
  end

  defp filter_calls_for_date(calls, %Date{} = timeline_date) do
    Enum.filter(calls, fn call ->
      call.started_at && DateTime.to_date(call.started_at) == timeline_date
    end)
  end

  defp filter_calls_for_date(calls, _timeline_date), do: calls

  defp calculate_timeline_dates(calls) do
    calls
    |> Enum.filter(& &1.started_at)
    |> Enum.map(&DateTime.to_date(&1.started_at))
    |> Enum.uniq()
  end

  defp moving_average(values, window) when is_list(values) and window > 0 do
    size = length(values)
    radius = div(window, 2)

    values
    |> Enum.with_index()
    |> Enum.map(fn {_value, idx} ->
      start_index = max(idx - radius, 0)
      end_index = min(idx + radius, size - 1)
      slice = Enum.slice(values, start_index..end_index)
      Enum.sum(slice) / max(length(slice), 1)
    end)
  end

  defp compute_max_hours(values, trend_values) do
    max_value =
      [Enum.max(values, fn -> 0 end), Enum.max(trend_values, fn -> 0 end)]
      |> Enum.max()

    step = if max_value <= 1.5, do: 0.25, else: 0.5

    if max_value > 0 do
      :math.ceil(max_value / step) * step
    else
      0.0
    end
  end

  defp build_y_labels(max_hours) do
    Enum.map(4..1//-1, fn step ->
      format_hours_label(max_hours * step / 4)
    end)
  end

  defp format_hours_label(value) do
    total_minutes = Float.round(value * 60, 0) |> trunc()

    if total_minutes >= 60 do
      hours = div(total_minutes, 60)
      minutes = rem(total_minutes, 60)
      "#{hours}h #{minutes}m"
    else
      "#{total_minutes}m"
    end
  end

  defp format_hour_label(0), do: "12 am"
  defp format_hour_label(12), do: "12 pm"
  defp format_hour_label(hour) when hour < 12, do: "#{hour} am"
  defp format_hour_label(hour), do: "#{hour - 12} pm"

  @doc """
  Calculate duration buckets distribution.
  """
  def calculate_duration_buckets(calls) do
    buckets = [
      {0, 30, "<30s"},
      {30, 120, "30s-2m"},
      {120, 300, "2-5m"},
      {300, 900, "5-15m"},
      {900, :infinity, "15m+"}
    ]

    counts =
      Enum.map(buckets, fn {min, max, _label} ->
        Enum.count(calls, fn call ->
          duration = call.duration_seconds || 0

          cond do
            max == :infinity -> duration >= min
            true -> duration >= min and duration < max
          end
        end)
      end)

    labels = Enum.map(buckets, fn {_, _, label} -> label end)

    %{labels: labels, values: counts}
  end

  @doc """
  Calculate top phone numbers (callers or receivers).
  """
  def calculate_top_numbers(calls, field, limit \\ 10) do
    calls
    |> Enum.filter(&Map.get(&1, field))
    |> Enum.group_by(&Map.get(&1, field))
    |> Enum.map(fn {number, calls_list} ->
      %{
        number: number,
        count: length(calls_list),
        total_duration: Enum.sum(Enum.map(calls_list, &(&1.duration_seconds || 0))),
        last_call: calls_list |> Enum.max_by(& &1.started_at, DateTime, fn -> nil end)
      }
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Calculate coverage metrics (recording, transcript, summary, disposition).
  """
  def calculate_coverage(calls) do
    total = max(length(calls), 1)

    with_recording = Enum.count(calls, &(&1.recording && map_size(&1.recording) > 0))
    with_transcript = Enum.count(calls, &(&1.transcript && map_size(&1.transcript) > 0))
    with_summary = Enum.count(calls, &(&1.summary && String.length(&1.summary || "") > 0))

    with_disposition =
      Enum.count(calls, &(&1.disposition && String.length(&1.disposition || "") > 0))

    %{
      recording: %{count: with_recording, percent: Float.round(with_recording / total * 100, 1)},
      transcript: %{
        count: with_transcript,
        percent: Float.round(with_transcript / total * 100, 1)
      },
      summary: %{count: with_summary, percent: Float.round(with_summary / total * 100, 1)},
      disposition: %{
        count: with_disposition,
        percent: Float.round(with_disposition / total * 100, 1)
      },
      missing_recording: total - with_recording,
      missing_transcript: total - with_transcript,
      missing_summary: total - with_summary,
      missing_disposition: total - with_disposition
    }
  end

  @doc """
  Calculate outliers (longest calls, zero-duration ended, stuck in progress).
  """
  def calculate_outliers(calls) do
    now = DateTime.utc_now()

    longest_calls =
      calls
      |> Enum.filter(&(&1.duration_seconds && &1.duration_seconds > 0))
      |> Enum.sort_by(& &1.duration_seconds, :desc)
      |> Enum.take(5)

    zero_duration_ended =
      calls
      |> Enum.filter(
        &(&1.status == :ended && (&1.duration_seconds == 0 || is_nil(&1.duration_seconds)))
      )
      |> Enum.take(10)

    # Calls stuck in_progress for more than 30 minutes
    stuck_in_progress =
      calls
      |> Enum.filter(fn call ->
        call.status == :in_progress &&
          call.started_at &&
          DateTime.diff(now, call.started_at, :minute) > 30
      end)
      |> Enum.sort_by(&DateTime.diff(now, &1.started_at, :minute), :desc)
      |> Enum.take(10)

    %{
      longest_calls: longest_calls,
      zero_duration_ended: zero_duration_ended,
      stuck_in_progress: stuck_in_progress
    }
  end

  @doc """
  Calculate agent leaderboard stats.
  """
  def calculate_agent_leaderboard(tenant_id, calls) do
    # Get all agents
    agents =
      Agent
      |> Tenancy.scope(tenant_id)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    # Group calls by agent
    by_agent =
      calls
      |> Enum.group_by(& &1.agent_id)

    # Calculate stats for each agent
    agent_stats =
      Enum.map(by_agent, fn {agent_id, agent_calls} ->
        agent = Map.get(agents, agent_id)
        total = length(agent_calls)
        ended = Enum.count(agent_calls, &(&1.status == :ended))

        durations =
          agent_calls
          |> Enum.filter(&(&1.duration_seconds && &1.duration_seconds > 0))
          |> Enum.map(& &1.duration_seconds)

        avg_duration =
          if length(durations) > 0, do: Enum.sum(durations) / length(durations), else: 0

        max_duration = if length(durations) > 0, do: Enum.max(durations), else: 0

        %{
          agent_id: agent_id,
          agent_name: if(agent, do: agent.name, else: "Unassigned"),
          total_calls: total,
          completed_calls: ended,
          completion_rate: if(total > 0, do: Float.round(ended / total * 100, 1), else: 0),
          avg_duration: Float.round(avg_duration, 0),
          max_duration: max_duration,
          total_talk_time: Enum.sum(durations)
        }
      end)
      |> Enum.sort_by(& &1.total_calls, :desc)

    # Format for chart
    chart_data = %{
      labels: Enum.map(agent_stats, & &1.agent_name),
      values: Enum.map(agent_stats, & &1.total_calls)
    }

    %{stats: agent_stats, chart_data: chart_data}
  end
end
