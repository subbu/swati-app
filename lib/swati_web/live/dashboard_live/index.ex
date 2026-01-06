defmodule SwatiWeb.DashboardLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Calls.Dashboard

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="dashboard-container">
        <%!-- Header --%>
        <header class="flex flex-col sm:flex-row sm:items-center gap-4 mb-8">
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <.icon name="hero-chart-bar-square" class="w-6 h-6 text-white" />
            </div>
            <div>
              <h1 class="text-2xl font-bold tracking-tight" style="color: var(--dash-text-primary)">
                Dashboard
              </h1>
              <p class="text-sm" style="color: var(--dash-text-tertiary)">
                Analytics and insights for your calls
              </p>
            </div>
          </div>

          <div class="sm:ml-auto flex items-center gap-3">
            <.dropdown placement="bottom-end">
              <:toggle>
                <button
                  class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all hover:shadow-md"
                  style="background: var(--dash-surface-1); border: 1px solid var(--dash-border); color: var(--dash-text-secondary)"
                >
                  <.icon name="hero-calendar" class="w-4 h-4" style="color: var(--dash-text-muted)" />
                  <span>{date_range_label(@date_range)}</span>
                  <.icon
                    name="hero-chevron-down"
                    class="w-3.5 h-3.5"
                    style="color: var(--dash-text-muted)"
                  />
                </button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("set_date_range", value: %{range: "7d"})}>
                Last 7 days
              </.dropdown_button>
              <.dropdown_button phx-click={JS.push("set_date_range", value: %{range: "14d"})}>
                Last 14 days
              </.dropdown_button>
              <.dropdown_button phx-click={JS.push("set_date_range", value: %{range: "30d"})}>
                Last 30 days
              </.dropdown_button>
              <.dropdown_button phx-click={JS.push("set_date_range", value: %{range: "90d"})}>
                Last 90 days
              </.dropdown_button>
            </.dropdown>

            <.dropdown placement="bottom-end">
              <:toggle>
                <button
                  class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all hover:shadow-md"
                  style="background: var(--dash-surface-1); border: 1px solid var(--dash-border); color: var(--dash-text-secondary)"
                >
                  <.icon
                    name="hero-user-circle"
                    class="w-4 h-4"
                    style="color: var(--dash-text-muted)"
                  />
                  <span>{agent_filter_label(@selected_agent_id, @agents)}</span>
                  <.icon
                    name="hero-chevron-down"
                    class="w-3.5 h-3.5"
                    style="color: var(--dash-text-muted)"
                  />
                </button>
              </:toggle>
              <.dropdown_button phx-click={JS.push("filter", value: %{agent_id: ""})}>
                All agents
              </.dropdown_button>
              <.dropdown_button
                :for={agent <- @agents}
                phx-click={JS.push("filter", value: %{agent_id: agent.id})}
              >
                {agent.name}
              </.dropdown_button>
            </.dropdown>
          </div>
        </header>

        <%!-- KPI Grid --%>
        <section class="kpi-grid mb-8" data-animate>
          <.kpi_card
            title="Total Calls"
            value={@stats.kpis.total_calls}
            icon="hero-phone"
            color="blue"
            sparkline={@stats.kpis.trend_sparkline}
          />
          <.kpi_card
            title="Completion"
            value={"#{@stats.kpis.completion_rate}%"}
            subtitle={"#{@stats.kpis.completed_calls} completed"}
            icon="hero-check-circle"
            color="green"
          />
          <.kpi_card
            title="Failure Rate"
            value={"#{@stats.kpis.failure_rate}%"}
            icon="hero-x-circle"
            color="red"
          />
          <.kpi_card
            title="Avg Duration"
            value={format_duration_short(@stats.kpis.avg_duration)}
            subtitle={"Median: #{format_duration_short(@stats.kpis.median_duration)}"}
            icon="hero-clock"
            color="amber"
          />
          <.kpi_card
            title="Median"
            value={format_duration_short(@stats.kpis.median_duration)}
            icon="hero-arrows-pointing-in"
            color="cyan"
          />
          <.kpi_card
            title="Talk Time"
            value={format_duration_long(@stats.kpis.total_talk_time)}
            icon="hero-chat-bubble-left-right"
            color="purple"
          />
        </section>

        <%!-- Main Charts Row --%>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <%!-- Calls Trend --%>
          <div class="lg:col-span-2 dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Calls Trend</h2>
                <p class="dashboard-card__subtitle">by status over time</p>
              </div>
            </div>
            <div class="dashboard-card__chart dashboard-card__chart--lg">
              <canvas
                id="calls-trend-chart"
                phx-hook="CallsTrendChart"
                data-chart-data={Jason.encode!(@stats.calls_trend)}
              />
            </div>
          </div>

          <%!-- Status Breakdown --%>
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Status Breakdown</h2>
                <p class="dashboard-card__subtitle">{@stats.kpis.total_calls} total calls</p>
              </div>
            </div>
            <div class="dashboard-card__chart">
              <canvas
                id="status-funnel-chart"
                phx-hook="StatusFunnelChart"
                data-chart-data={Jason.encode!(@stats.status_breakdown)}
              />
            </div>
          </div>
        </div>

        <%!-- Popular Times + Peak Hours --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Popular Times</h2>
                <p class="dashboard-card__subtitle">average calls per hour</p>
              </div>
            </div>
            <div class="dashboard-card__chart dashboard-card__chart--sm">
              <canvas
                id="popular-times-chart"
                phx-hook="PopularTimesChart"
                data-chart-data={Jason.encode!(@stats.popular_times)}
              />
            </div>
          </div>

          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Peak Hours</h2>
                <p class="dashboard-card__subtitle">call volume by day & hour</p>
              </div>
            </div>
            <div class="dashboard-card__chart dashboard-card__chart--sm">
              <canvas
                id="peak-hours-heatmap"
                phx-hook="PeakHoursHeatmap"
                data-chart-data={Jason.encode!(@stats.peak_hours_matrix)}
              />
            </div>
          </div>
        </div>

        <%!-- Duration + Agent Leaderboard --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Duration Distribution</h2>
                <p class="dashboard-card__subtitle">call length buckets</p>
              </div>
            </div>
            <div class="dashboard-card__chart">
              <canvas
                id="duration-buckets-chart"
                phx-hook="DurationBucketsChart"
                data-chart-data={Jason.encode!(@stats.duration_buckets)}
              />
            </div>
          </div>

          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Agent Leaderboard</h2>
                <p class="dashboard-card__subtitle">calls handled</p>
              </div>
            </div>
            <div class="dashboard-card__chart">
              <canvas
                id="agent-leaderboard-chart"
                phx-hook="AgentLeaderboardChart"
                data-chart-data={Jason.encode!(@stats.agent_leaderboard.chart_data)}
              />
            </div>
          </div>
        </div>

        <%!-- Top Numbers + Coverage --%>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <%!-- Top Callers --%>
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Top Callers</h2>
                <p class="dashboard-card__subtitle">repeat callers by count</p>
              </div>
            </div>
            <div class="data-list max-h-64 overflow-y-auto">
              <div
                :for={{item, idx} <- Enum.with_index(@stats.top_from_numbers)}
                class="data-list__item"
              >
                <span class="data-list__rank">{idx + 1}</span>
                <span class="data-list__value">{item.number}</span>
                <span class="data-list__count">{item.count}</span>
              </div>
              <div :if={@stats.top_from_numbers == []} class="data-list__empty">
                No callers yet
              </div>
            </div>
          </div>

          <%!-- Top Lines --%>
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Top Lines</h2>
                <p class="dashboard-card__subtitle">most active numbers</p>
              </div>
            </div>
            <div class="data-list max-h-64 overflow-y-auto">
              <div
                :for={{item, idx} <- Enum.with_index(@stats.top_to_numbers)}
                class="data-list__item"
              >
                <span class="data-list__rank">{idx + 1}</span>
                <span class="data-list__value">{item.number}</span>
                <span class="data-list__count">{item.count}</span>
              </div>
              <div :if={@stats.top_to_numbers == []} class="data-list__empty">
                No lines yet
              </div>
            </div>
          </div>

          <%!-- Coverage --%>
          <div class="dashboard-card" data-animate>
            <div class="dashboard-card__header">
              <div>
                <h2 class="dashboard-card__title">Coverage</h2>
                <p class="dashboard-card__subtitle">data completeness</p>
              </div>
            </div>
            <div class="space-y-4">
              <.coverage_bar
                label="Recording"
                value={@stats.coverage.recording.percent}
                count={@stats.coverage.recording.count}
              />
              <.coverage_bar
                label="Transcript"
                value={@stats.coverage.transcript.percent}
                count={@stats.coverage.transcript.count}
              />
              <.coverage_bar
                label="Summary"
                value={@stats.coverage.summary.percent}
                count={@stats.coverage.summary.count}
              />
              <.coverage_bar
                label="Disposition"
                value={@stats.coverage.disposition.percent}
                count={@stats.coverage.disposition.count}
              />
            </div>
          </div>
        </div>

        <%!-- Agent Performance Table --%>
        <div class="dashboard-card mb-6" data-animate>
          <div class="dashboard-card__header">
            <div>
              <h2 class="dashboard-card__title">Agent Performance</h2>
              <p class="dashboard-card__subtitle">{length(@stats.agent_leaderboard.stats)} agents</p>
            </div>
          </div>
          <div class="dashboard-table-wrapper">
            <table class="dashboard-table">
              <thead>
                <tr>
                  <th>Agent</th>
                  <th class="text-right">Calls</th>
                  <th class="text-right">Completed</th>
                  <th class="text-right">Rate</th>
                  <th class="text-right hidden sm:table-cell">Avg Duration</th>
                  <th class="text-right hidden md:table-cell">Longest</th>
                  <th class="text-right hidden lg:table-cell">Total Time</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={agent <- @stats.agent_leaderboard.stats}
                  class="cursor-pointer"
                  phx-click={JS.push("filter", value: %{agent_id: agent.agent_id})}
                >
                  <td>
                    <div class="flex items-center gap-3">
                      <div class={"agent-avatar #{agent_avatar_class(agent.agent_name)}"}>
                        {String.first(agent.agent_name)}
                      </div>
                      <div>
                        <span class="dashboard-table__cell--primary">{agent.agent_name}</span>
                        <span
                          :if={is_nil(agent.agent_id)}
                          class="ml-2 text-xs px-1.5 py-0.5 rounded-full"
                          style="background: var(--dash-accent-amber-soft); color: var(--dash-accent-amber)"
                        >
                          unassigned
                        </span>
                      </div>
                    </div>
                  </td>
                  <td class="text-right dashboard-table__cell--mono">{agent.total_calls}</td>
                  <td class="text-right dashboard-table__cell--mono">{agent.completed_calls}</td>
                  <td class={"text-right #{rate_class(agent.completion_rate)}"}>
                    {agent.completion_rate}%
                  </td>
                  <td class="text-right dashboard-table__cell--mono hidden sm:table-cell">
                    {format_duration_short(agent.avg_duration)}
                  </td>
                  <td class="text-right dashboard-table__cell--mono hidden md:table-cell">
                    {format_duration_short(agent.max_duration)}
                  </td>
                  <td class="text-right dashboard-table__cell--mono hidden lg:table-cell">
                    {format_duration_long(agent.total_talk_time)}
                  </td>
                </tr>
              </tbody>
            </table>
            <div :if={@stats.agent_leaderboard.stats == []} class="data-list__empty">
              No agent data available
            </div>
          </div>
        </div>

        <%!-- Outliers Row --%>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Longest Calls --%>
          <div class="outlier-card" data-animate>
            <div class="outlier-card__header">
              <h2 class="outlier-card__title">Longest Calls</h2>
              <.icon
                name="hero-arrow-trending-up"
                class="w-4 h-4"
                style="color: var(--dash-text-muted)"
              />
            </div>
            <div>
              <.link
                :for={call <- @stats.outliers.longest_calls}
                navigate={~p"/calls/#{call.id}"}
                class="outlier-card__item outlier-card__item--with-bar"
              >
                <div class="outlier-card__item-content">
                  <span class="outlier-card__item-date">{format_datetime_short(call.started_at)}</span>
                  <span class="outlier-card__item-value">
                    {format_duration_long(call.duration_seconds)}
                  </span>
                </div>
                <div class="outlier-card__duration-bar">
                  <div
                    class="outlier-card__duration-fill"
                    style={"width: #{duration_percentage(call.duration_seconds, @stats.outliers.longest_calls)}%"}
                  />
                </div>
              </.link>
              <div :if={@stats.outliers.longest_calls == []} class="data-list__empty">
                No data yet
              </div>
            </div>
          </div>

          <%!-- Zero Duration --%>
          <div class="outlier-card" data-animate>
            <div class="outlier-card__header">
              <h2 class="outlier-card__title">Zero-Duration Ended</h2>
              <span class={"outlier-card__badge #{if length(@stats.outliers.zero_duration_ended) > 0, do: "outlier-card__badge--warning", else: "outlier-card__badge--success"}"}>
                {length(@stats.outliers.zero_duration_ended)}
              </span>
            </div>
            <div>
              <.link
                :for={call <- Enum.take(@stats.outliers.zero_duration_ended, 5)}
                navigate={~p"/calls/#{call.id}"}
                class="outlier-card__item"
              >
                <span class="outlier-card__item-date">{format_datetime_short(call.started_at)}</span>
                <span class="outlier-card__item-value text-xs">{call.from_number}</span>
              </.link>
              <div :if={@stats.outliers.zero_duration_ended == []} class="outlier-card__empty">
                None found
              </div>
            </div>
          </div>

          <%!-- Stuck In Progress --%>
          <div class="outlier-card" data-animate>
            <div class="outlier-card__header">
              <h2 class="outlier-card__title">Stuck In Progress</h2>
              <span class={"outlier-card__badge #{if length(@stats.outliers.stuck_in_progress) > 0, do: "outlier-card__badge--danger", else: "outlier-card__badge--success"}"}>
                {length(@stats.outliers.stuck_in_progress)}
              </span>
            </div>
            <div>
              <.link
                :for={call <- Enum.take(@stats.outliers.stuck_in_progress, 5)}
                navigate={~p"/calls/#{call.id}"}
                class="outlier-card__item"
              >
                <span class="outlier-card__item-date">{format_datetime_short(call.started_at)}</span>
                <span class="outlier-card__item-value" style="color: var(--dash-accent-red)">
                  {stuck_duration(call)}
                </span>
              </.link>
              <div :if={@stats.outliers.stuck_in_progress == []} class="outlier-card__empty">
                None found
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # Components

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :subtitle, :string, default: nil
  attr :sparkline, :list, default: nil
  attr :color, :string, default: "blue"

  defp kpi_card(assigns) do
    ~H"""
    <div class={"kpi-card kpi-card--#{@color}"} data-animate>
      <div class="kpi-card__header">
        <div class="kpi-card__icon">
          <.icon name={@icon} class="w-4 h-4" />
        </div>
        <span class="kpi-card__title">{@title}</span>
      </div>
      <div class="kpi-card__value">{@value}</div>
      <div :if={@subtitle} class="kpi-card__subtitle">{@subtitle}</div>
      <div :if={@sparkline} class="kpi-card__sparkline">
        <canvas
          id={"sparkline-#{@title |> String.downcase() |> String.replace(~r/[^a-z0-9]/, "-")}"}
          phx-hook="KPISparkline"
          data-values={Jason.encode!(@sparkline)}
          data-color={sparkline_color(@color)}
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :float, required: true
  attr :count, :integer, required: true

  defp coverage_bar(assigns) do
    ~H"""
    <div class="coverage-item">
      <div class="coverage-item__header">
        <span class="coverage-item__label">{@label}</span>
        <span class="coverage-item__value">{@value}%</span>
      </div>
      <div class="coverage-item__bar">
        <div class="coverage-item__fill" style={"width: #{@value}%"} />
      </div>
      <div class="coverage-item__meta">{@count} calls</div>
    </div>
    """
  end

  # Lifecycle

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)

    date_range = "30d"
    {start_date, end_date} = parse_date_range(date_range)

    stats = Dashboard.get_dashboard_stats(tenant.id, start_date: start_date, end_date: end_date)

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:date_range, date_range)
     |> assign(:selected_agent_id, nil)
     |> assign(:stats, stats)
     |> assign(:filter_form, to_form(%{}))}
  end

  @impl true
  def handle_event("set_date_range", %{"range" => range}, socket) do
    {start_date, end_date} = parse_date_range(range)
    tenant = socket.assigns.current_scope.tenant

    stats =
      Dashboard.get_dashboard_stats(tenant.id,
        start_date: start_date,
        end_date: end_date,
        agent_id: socket.assigns.selected_agent_id
      )

    {:noreply,
     socket
     |> assign(:date_range, range)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("filter", %{"agent_id" => agent_id}, socket) do
    {start_date, end_date} = parse_date_range(socket.assigns.date_range)
    tenant = socket.assigns.current_scope.tenant

    agent_id = if agent_id == "", do: nil, else: agent_id

    stats =
      Dashboard.get_dashboard_stats(tenant.id,
        start_date: start_date,
        end_date: end_date,
        agent_id: agent_id
      )

    {:noreply,
     socket
     |> assign(:selected_agent_id, agent_id)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_event("filter", _params, socket) do
    {:noreply, socket}
  end

  # Helpers

  defp parse_date_range(range) do
    now = DateTime.utc_now()

    days =
      case range do
        "7d" -> 7
        "14d" -> 14
        "30d" -> 30
        "90d" -> 90
        _ -> 30
      end

    start_date = DateTime.add(now, -days, :day)
    {start_date, now}
  end

  defp date_range_label("7d"), do: "Last 7 days"
  defp date_range_label("14d"), do: "Last 14 days"
  defp date_range_label("30d"), do: "Last 30 days"
  defp date_range_label("90d"), do: "Last 90 days"
  defp date_range_label(_), do: "Last 30 days"

  defp agent_filter_label(nil, _agents), do: "All agents"
  defp agent_filter_label("", _agents), do: "All agents"

  defp agent_filter_label(agent_id, agents) do
    case Enum.find(agents, &(to_string(&1.id) == to_string(agent_id))) do
      nil -> "All agents"
      agent -> agent.name
    end
  end

  defp format_duration_short(nil), do: "—"
  defp format_duration_short(0), do: "0s"

  defp format_duration_short(seconds) when is_number(seconds) and seconds == 0, do: "0s"

  defp format_duration_short(seconds) when is_number(seconds) do
    seconds = trunc(seconds)

    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m"
    end
  end

  defp format_duration_long(nil), do: "—"
  defp format_duration_long(0), do: "0s"

  defp format_duration_long(seconds) when is_number(seconds) do
    seconds = trunc(seconds)

    cond do
      seconds < 60 -> "#{seconds}s"
      seconds < 3600 -> "#{div(seconds, 60)}m #{rem(seconds, 60)}s"
      true -> "#{div(seconds, 3600)}h #{div(rem(seconds, 3600), 60)}m"
    end
  end

  defp format_datetime_short(nil), do: "—"

  defp format_datetime_short(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d %H:%M")
  end

  defp stuck_duration(call) do
    minutes = DateTime.diff(DateTime.utc_now(), call.started_at, :minute)

    cond do
      minutes < 60 -> "#{minutes}m stuck"
      true -> "#{div(minutes, 60)}h #{rem(minutes, 60)}m stuck"
    end
  end

  defp rate_class(rate) when rate >= 80, do: "dashboard-table__cell--success"
  defp rate_class(rate) when rate >= 60, do: "dashboard-table__cell--warning"
  defp rate_class(_rate), do: "dashboard-table__cell--danger"

  defp agent_avatar_class(name) do
    colors = [
      "agent-avatar--blue",
      "agent-avatar--green",
      "agent-avatar--amber",
      "agent-avatar--red",
      "agent-avatar--purple",
      "agent-avatar--cyan"
    ]

    index = :erlang.phash2(name) |> rem(length(colors))
    Enum.at(colors, index)
  end

  defp sparkline_color("blue"), do: "oklch(62% 0.19 255)"
  defp sparkline_color("green"), do: "oklch(65% 0.17 155)"
  defp sparkline_color("red"), do: "oklch(62% 0.22 25)"
  defp sparkline_color("amber"), do: "oklch(75% 0.16 75)"
  defp sparkline_color("cyan"), do: "oklch(70% 0.14 200)"
  defp sparkline_color("purple"), do: "oklch(60% 0.2 295)"
  defp sparkline_color(_), do: "oklch(62% 0.19 255)"

  defp duration_percentage(duration, calls) when is_list(calls) and length(calls) > 0 do
    max_duration =
      calls
      |> Enum.map(& &1.duration_seconds)
      |> Enum.filter(&(&1 && &1 > 0))
      |> Enum.max(fn -> 1 end)

    if max_duration > 0 do
      Float.round((duration || 0) / max_duration * 100, 1)
    else
      0
    end
  end

  defp duration_percentage(_, _), do: 0
end
