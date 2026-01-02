defmodule Swati.Workers.SummarizeCall do
  use Oban.Worker, queue: :calls

  alias Swati.Calls

  @impl true
  def perform(%Oban.Job{args: %{"call_id" => call_id}}) do
    _ = Calls.set_call_summary(call_id, "pending", "pending")
    :ok
  end

  def perform(%Oban.Job{}), do: :ok
end
