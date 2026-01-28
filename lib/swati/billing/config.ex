defmodule Swati.Billing.Config do
  def grace_period_days do
    config()
    |> Keyword.get(:grace_period_days, 7)
  end

  def grace_notification_offsets_hours do
    config()
    |> Keyword.get(:grace_notification_offsets_hours, [0, 24, 72, 144, 168])
  end

  def subscription_total_count do
    config()
    |> Keyword.get(:subscription_total_count, 120)
  end

  def subscription_customer_notify do
    config()
    |> Keyword.get(:subscription_customer_notify, true)
  end

  defp config do
    Application.get_env(:swati, :billing, [])
  end
end
