defmodule Swati.Billing.ProviderSubscription do
  use Swati.DbSchema

  schema "provider_subscriptions" do
    field :provider, :string
    field :provider_subscription_id, :string
    field :provider_customer_id, :string
    field :provider_plan_id, :string
    field :provider_status, :string
    field :quantity, :integer, default: 1
    field :current_start_at, :utc_datetime_usec
    field :current_end_at, :utc_datetime_usec
    field :next_charge_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    timestamps()
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :provider,
      :provider_subscription_id,
      :provider_customer_id,
      :provider_plan_id,
      :provider_status,
      :quantity,
      :current_start_at,
      :current_end_at,
      :next_charge_at,
      :cancelled_at,
      :metadata
    ])
    |> validate_required([:provider, :provider_subscription_id])
    |> unique_constraint([:provider, :provider_subscription_id])
  end
end
