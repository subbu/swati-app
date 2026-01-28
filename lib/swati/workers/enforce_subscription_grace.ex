defmodule Swati.Workers.EnforceSubscriptionGrace do
  use Oban.Worker, queue: :billing, max_attempts: 3

  alias Swati.Billing.Grace

  @impl true
  def perform(%Oban.Job{args: %{"tenant_subscription_id" => subscription_id, "reason" => reason}}) do
    Grace.enforce(subscription_id, reason)
    :ok
  end
end
