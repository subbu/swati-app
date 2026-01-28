defmodule Swati.Workers.SendBillingNotification do
  use Oban.Worker, queue: :billing, max_attempts: 3

  alias Swati.Billing.Notifications

  @impl true
  def perform(%Oban.Job{args: %{"tenant_subscription_id" => subscription_id, "kind" => kind}}) do
    Notifications.send_notification(subscription_id, kind)
    :ok
  end
end
