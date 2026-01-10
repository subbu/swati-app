import Chart from "chart.js/auto";
import "chartjs-adapter-date-fns";

// Helper to ensure chart container has dimensions
const waitForDimensions = (el, maxAttempts = 10) => {
  return new Promise((resolve) => {
    let attempts = 0;
    const check = () => {
      const rect = el.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        resolve(true);
      } else if (attempts < maxAttempts) {
        attempts++;
        requestAnimationFrame(check);
      } else {
        resolve(false);
      }
    };
    check();
  });
};

// Custom plugin for glowing effect on hover
const glowPlugin = {
  id: "glow",
  beforeDatasetDraw(chart) {
    const ctx = chart.ctx;
    ctx.save();
    ctx.shadowColor = "rgba(99, 102, 241, 0.5)";
    ctx.shadowBlur = 10;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 0;
  },
  afterDatasetDraw(chart) {
    chart.ctx.restore();
  },
};

// Shared chart defaults for light theme (matching dashboard CSS)
const chartDefaults = {
  color: "rgba(60, 60, 70, 0.7)",
  borderColor: "rgba(60, 60, 70, 0.1)",
  font: {
    family: "system-ui, -apple-system, sans-serif",
    weight: 400,
  },
};

// Color palette matching the app's design system
const colors = {
  primary: "rgba(99, 102, 241, 1)",
  primaryFaded: "rgba(99, 102, 241, 0.2)",
  success: "rgba(34, 197, 94, 1)",
  successFaded: "rgba(34, 197, 94, 0.2)",
  warning: "rgba(245, 158, 11, 1)",
  warningFaded: "rgba(245, 158, 11, 0.2)",
  error: "rgba(239, 68, 68, 1)",
  errorFaded: "rgba(239, 68, 68, 0.2)",
  info: "rgba(59, 130, 246, 1)",
  infoFaded: "rgba(59, 130, 246, 0.2)",
  neutral: "rgba(113, 113, 122, 1)",
  neutralFaded: "rgba(113, 113, 122, 0.2)",
  accent: "rgba(168, 85, 247, 1)",
  accentFaded: "rgba(168, 85, 247, 0.2)",
};

// Status colors mapping
const statusColors = {
  ended: colors.success,
  in_progress: colors.info,
  started: colors.primary,
  failed: colors.error,
  cancelled: colors.neutral,
  error: colors.warning,
};

const statusColorsFaded = {
  ended: colors.successFaded,
  in_progress: colors.infoFaded,
  started: colors.primaryFaded,
  failed: colors.errorFaded,
  cancelled: colors.neutralFaded,
  error: colors.warningFaded,
};

// Apply defaults
Chart.defaults.color = chartDefaults.color;
Chart.defaults.borderColor = chartDefaults.borderColor;
Chart.defaults.font.family = chartDefaults.font.family;

// KPI Sparkline Mini Chart
export const KPISparkline = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_sparkline", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.values || "[]");
    const color = this.el.dataset.color || colors.primary;

    return new Chart(ctx, {
      type: "line",
      data: {
        labels: data.map((_, i) => i),
        datasets: [
          {
            data: data,
            borderColor: color,
            borderWidth: 2,
            fill: true,
            backgroundColor: color.replace("1)", "0.1)"),
            tension: 0.4,
            pointRadius: 0,
            pointHoverRadius: 0,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false }, tooltip: { enabled: false } },
        scales: {
          x: { display: false },
          y: { display: false },
        },
        animation: { duration: 500 },
      },
    });
  },

  updateChart({ values }) {
    this.chart.data.datasets[0].data = values;
    this.chart.data.labels = values.map((_, i) => i);
    this.chart.update("none");
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Calls Trend Line Chart
export const CallsTrendChart = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_trend", (data) => this.recreateChart());

    // Handle resize
    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    // Destroy and recreate chart to handle data structure changes
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");

    return new Chart(ctx, {
      type: "line",
      data: {
        labels: data.labels || [],
        datasets: (data.datasets || []).map((ds, i) => ({
          ...ds,
          borderColor: statusColors[ds.status] || colors.primary,
          backgroundColor: statusColorsFaded[ds.status] || colors.primaryFaded,
          borderWidth: 2,
          fill: true,
          tension: 0.3,
          pointRadius: 0,
          pointHoverRadius: 4,
          pointHoverBackgroundColor: statusColors[ds.status] || colors.primary,
        })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              boxWidth: 12,
              boxHeight: 12,
              borderRadius: 2,
              padding: 16,
              usePointStyle: true,
              pointStyle: "rectRounded",
            },
          },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            displayColors: true,
            boxWidth: 8,
            boxHeight: 8,
            boxPadding: 4,
          },
        },
        scales: {
          x: {
            grid: { display: false },
            border: { display: false },
            ticks: { padding: 8 },
          },
          y: {
            beginAtZero: true,
            grid: {
              color: "rgba(0, 0, 0, 0.06)",
              drawTicks: false,
            },
            border: { display: false },
            ticks: { padding: 12, stepSize: 5 },
          },
        },
      },
    });
  },

  updateChart(data) {
    this.chart.data.labels = data.labels;
    this.chart.data.datasets = (data.datasets || []).map((ds) => ({
      ...ds,
      borderColor: statusColors[ds.status] || colors.primary,
      backgroundColor: statusColorsFaded[ds.status] || colors.primaryFaded,
      borderWidth: 2,
      fill: true,
      tension: 0.3,
      pointRadius: 0,
      pointHoverRadius: 4,
    }));
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Status Funnel / Doughnut Chart
export const StatusFunnelChart = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_funnel", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");

    return new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: (data.statuses || []).map(
              (s) => statusColors[s] || colors.neutral
            ),
            borderWidth: 0,
            hoverOffset: 8,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "70%",
        plugins: {
          legend: {
            position: "right",
            labels: {
              boxWidth: 12,
              boxHeight: 12,
              padding: 12,
              usePointStyle: true,
              pointStyle: "rectRounded",
            },
          },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
          },
        },
      },
    });
  },

  updateChart(data) {
    this.chart.data.labels = data.labels;
    this.chart.data.datasets[0].data = data.values;
    this.chart.data.datasets[0].backgroundColor = (data.statuses || []).map(
      (s) => statusColors[s] || colors.neutral
    );
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Peak Hours Heatmap
export const PeakHoursHeatmap = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_heatmap", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");
    const matrix = data.matrix || [];
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const hours = Array.from({ length: 24 }, (_, i) =>
      i.toString().padStart(2, "0")
    );

    // Find max value for color scaling
    const maxVal = Math.max(1, ...matrix.flat());

    // Convert matrix to chart.js scatter format
    const points = [];
    matrix.forEach((row, dayIdx) => {
      row.forEach((val, hourIdx) => {
        points.push({
          x: hourIdx,
          y: dayIdx,
          v: val,
        });
      });
    });

    return new Chart(ctx, {
      type: "scatter",
      data: {
        datasets: [
          {
            data: points,
            backgroundColor: (ctx) => {
              const val = ctx.raw?.v || 0;
              const intensity = val / maxVal;
              if (intensity === 0) return "rgba(99, 102, 241, 0.08)";
              // Use a gradient from light to saturated
              const alpha = 0.25 + intensity * 0.75;
              return `rgba(99, 102, 241, ${alpha})`;
            },
            borderWidth: 1,
            borderColor: (ctx) => {
              const val = ctx.raw?.v || 0;
              const intensity = val / maxVal;
              if (intensity === 0) return "rgba(99, 102, 241, 0.1)";
              return `rgba(99, 102, 241, ${0.3 + intensity * 0.5})`;
            },
            pointRadius: (ctx) => {
              const chartArea = ctx.chart.chartArea;
              if (!chartArea) return 10;
              const cellWidth = (chartArea.right - chartArea.left) / 24;
              const cellHeight = (chartArea.bottom - chartArea.top) / 7;
              return Math.min(cellWidth, cellHeight) / 2.2;
            },
            pointStyle: "rect",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              title: (items) => {
                if (!items.length) return "";
                const { x, y } = items[0].raw;
                return `${days[y]} ${hours[x]}:00`;
              },
              label: (ctx) => `${ctx.raw.v} calls`,
            },
          },
        },
        scales: {
          x: {
            type: "linear",
            min: -0.5,
            max: 23.5,
            grid: { display: false },
            border: { display: false },
            ticks: {
              stepSize: 4,
              callback: (v) => {
                const hour = Math.round(v);
                if (hour === 0) return "12a";
                if (hour === 12) return "12p";
                if (hour < 12) return `${hour}a`;
                return `${hour - 12}p`;
              },
              padding: 8,
              font: { size: 10, weight: 500 },
              color: "rgba(60, 60, 70, 0.6)",
            },
          },
          y: {
            type: "linear",
            min: -0.5,
            max: 6.5,
            reverse: true,
            grid: { display: false },
            border: { display: false },
            ticks: {
              stepSize: 1,
              callback: (v) => {
                const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                return dayNames[Math.round(v)] || "";
              },
              padding: 8,
              font: { size: 10, weight: 500 },
              color: "rgba(60, 60, 70, 0.6)",
            },
          },
        },
      },
    });
  },

  updateChart(data) {
    const matrix = data.matrix || [];
    const maxVal = Math.max(1, ...matrix.flat());

    const points = [];
    matrix.forEach((row, dayIdx) => {
      row.forEach((val, hourIdx) => {
        points.push({ x: hourIdx, y: dayIdx, v: val });
      });
    });

    this.chart.data.datasets[0].data = points;
    this.chart.data.datasets[0].backgroundColor = (ctx) => {
      const val = ctx.raw?.v || 0;
      const intensity = val / maxVal;
      if (intensity === 0) return "rgba(99, 102, 241, 0.08)";
      return `rgba(99, 102, 241, ${0.25 + intensity * 0.75})`;
    };
    this.chart.data.datasets[0].borderColor = (ctx) => {
      const val = ctx.raw?.v || 0;
      const intensity = val / maxVal;
      if (intensity === 0) return "rgba(99, 102, 241, 0.1)";
      return `rgba(99, 102, 241, ${0.3 + intensity * 0.5})`;
    };
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Duration Buckets Bar Chart
export const DurationBucketsChart = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_buckets", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");

    return new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: colors.primaryFaded,
            borderColor: colors.primary,
            borderWidth: 1,
            borderRadius: 4,
            hoverBackgroundColor: colors.primary,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              label: (ctx) => `${ctx.raw} calls`,
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            border: { display: false },
            ticks: { padding: 8 },
          },
          y: {
            beginAtZero: true,
            grid: {
              color: "rgba(0, 0, 0, 0.06)",
              drawTicks: false,
            },
            border: { display: false },
            ticks: { padding: 12 },
          },
        },
      },
    });
  },

  updateChart(data) {
    this.chart.data.labels = data.labels;
    this.chart.data.datasets[0].data = data.values;
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Popular Times (Google Maps style)
export const PopularTimesChart = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_popular_times", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");
    const currentHour = new Date().getHours();

    return new Chart(ctx, {
      type: "bar",
      data: {
        labels: (data.labels || []).map((h) => {
          const hour = parseInt(h);
          if (hour === 0) return "12a";
          if (hour === 12) return "12p";
          return hour > 12 ? `${hour - 12}p` : `${hour}a`;
        }),
        datasets: [
          {
            data: data.values || [],
            backgroundColor: (ctx) => {
              const hour = parseInt(data.labels?.[ctx.dataIndex] || "0");
              return hour === currentHour ? colors.primary : colors.primaryFaded;
            },
            borderRadius: 4,
            borderSkipped: false,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
            callbacks: {
              title: (items) => {
                const hour = parseInt(data.labels?.[items[0].dataIndex] || "0");
                return `${hour}:00 - ${hour + 1}:00`;
              },
              label: (ctx) => `${ctx.raw} calls on average`,
            },
          },
        },
        scales: {
          x: {
            grid: { display: false },
            border: { display: false },
            ticks: {
              padding: 8,
              maxRotation: 0,
              callback: function (val, index) {
                // Show every 3rd label
                return index % 3 === 0 ? this.getLabelForValue(val) : "";
              },
            },
          },
          y: {
            display: false,
            beginAtZero: true,
          },
        },
      },
    });
  },

  updateChart(data) {
    const currentHour = new Date().getHours();
    this.chart.data.labels = (data.labels || []).map((h) => {
      const hour = parseInt(h);
      if (hour === 0) return "12a";
      if (hour === 12) return "12p";
      return hour > 12 ? `${hour - 12}p` : `${hour}a`;
    });
    this.chart.data.datasets[0].data = data.values;
    this.chart.data.datasets[0].backgroundColor = (ctx) => {
      const hour = parseInt(data.labels?.[ctx.dataIndex] || "0");
      return hour === currentHour ? colors.primary : colors.primaryFaded;
    };
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

// Agent Leaderboard Horizontal Bar
export const AgentLeaderboardChart = {
  async mounted() {
    await waitForDimensions(this.el);
    this.chart = this.createChart();
    this.handleEvent("update_leaderboard", (data) => this.recreateChart());

    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) this.chart.resize();
    });
    this.resizeObserver.observe(this.el.parentElement);
  },

  updated() {
    this.recreateChart();
  },

  recreateChart() {
    if (this.chart) {
      this.chart.destroy();
    }
    this.chart = this.createChart();
  },

  createChart() {
    const ctx = this.el.getContext("2d");
    const data = JSON.parse(this.el.dataset.chartData || "{}");

    return new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: colors.primaryFaded,
            borderColor: colors.primary,
            borderWidth: 1,
            borderRadius: 4,
            hoverBackgroundColor: colors.primary,
          },
        ],
      },
      options: {
        indexAxis: "y",
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(30, 30, 40, 0.95)",
            titleColor: "rgba(255, 255, 255, 0.95)",
            bodyColor: "rgba(255, 255, 255, 0.8)",
            borderColor: "rgba(255, 255, 255, 0.1)",
            borderWidth: 1,
            padding: 12,
            cornerRadius: 8,
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            grid: {
              color: "rgba(0, 0, 0, 0.06)",
              drawTicks: false,
            },
            border: { display: false },
            ticks: { padding: 8 },
          },
          y: {
            grid: { display: false },
            border: { display: false },
            ticks: { padding: 8 },
          },
        },
      },
    });
  },

  updateChart(data) {
    this.chart.data.labels = data.labels;
    this.chart.data.datasets[0].data = data.values;
    this.chart.update();
  },

  destroyed() {
    this.resizeObserver?.disconnect();
    this.chart?.destroy();
  },
};

export const DashboardHooks = {
  KPISparkline,
  CallsTrendChart,
  StatusFunnelChart,
  PeakHoursHeatmap,
  DurationBucketsChart,
  PopularTimesChart,
  AgentLeaderboardChart,
};
