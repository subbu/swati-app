defmodule Swati.Calls.CallStatusTransitions do
  @terminal_statuses [:ended, :failed, :cancelled, :error]

  def normalize_end_status(nil), do: nil

  def normalize_end_status(status) when is_binary(status) do
    String.downcase(status)
  end

  def normalize_end_status(status), do: status

  def terminal_status?(status) when is_atom(status) do
    status in @terminal_statuses
  end

  def terminal_status?(status) when is_binary(status) do
    downcased = String.downcase(status)
    Enum.any?(@terminal_statuses, &(Atom.to_string(&1) == downcased))
  end

  def terminal_status?(_status), do: false
end
