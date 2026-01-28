defmodule Swati.Workers.ProcessSubscriptionEvent do
  use Oban.Worker, queue: :billing, max_attempts: 5

  alias Swati.Billing

  @impl true
  def perform(%Oban.Job{args: %{"event_id" => event_id}}) do
    Billing.process_subscription_event(event_id)
    :ok
  end
end
