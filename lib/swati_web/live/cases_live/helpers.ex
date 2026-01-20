defmodule SwatiWeb.CasesLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting

  def status_badge(status) do
    case to_string(status || "") do
      "new" -> %{label: "New", color: "info"}
      "triage" -> %{label: "Triage", color: "warning"}
      "in_progress" -> %{label: "In progress", color: "success"}
      "waiting_on_customer" -> %{label: "Waiting", color: "warning"}
      "resolved" -> %{label: "Resolved", color: "neutral"}
      "closed" -> %{label: "Closed", color: "neutral"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def priority_badge(priority) do
    case to_string(priority || "") do
      "low" -> %{label: "Low", color: "neutral"}
      "normal" -> %{label: "Normal", color: "info"}
      "high" -> %{label: "High", color: "warning"}
      "urgent" -> %{label: "Urgent", color: "danger"}
      _ -> %{label: "Normal", color: "info"}
    end
  end

  def format_datetime(nil, _tenant), do: "—"

  def format_datetime(%DateTime{} = dt, tenant) do
    Formatting.datetime(dt, tenant)
  end

  def format_relative(nil, _tenant), do: "—"

  def format_relative(%DateTime{} = dt, _tenant) do
    seconds = max(DateTime.diff(DateTime.utc_now(), dt, :second), 0)

    cond do
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} hours ago"
      true -> "#{div(seconds, 86_400)} days ago"
    end
  end

  def customer_name(case_record) do
    case case_record.customer do
      nil -> "—"
      customer -> customer.name || customer.primary_email || customer.primary_phone || "Customer"
    end
  end
end
