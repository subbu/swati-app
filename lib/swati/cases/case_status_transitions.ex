defmodule Swati.Cases.CaseStatusTransitions do
  @statuses [:new, :triage, :in_progress, :waiting_on_customer, :resolved, :closed]

  def normalize_status(status) do
    case to_string(status || "") do
      "new" -> :new
      "triage" -> :triage
      "in_progress" -> :in_progress
      "waiting_on_customer" -> :waiting_on_customer
      "resolved" -> :resolved
      "closed" -> :closed
      _ -> :new
    end
  end

  def allowed_statuses, do: @statuses
end
