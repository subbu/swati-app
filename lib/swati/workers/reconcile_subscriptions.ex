defmodule Swati.Workers.ReconcileSubscriptions do
  use Oban.Worker, queue: :billing, max_attempts: 2

  alias Swati.Billing

  @impl true
  def perform(%Oban.Job{}) do
    Billing.reconcile_subscriptions()
    :ok
  end
end
