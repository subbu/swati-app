defmodule Swati.Billing.TenantSubscription do
  use Swati.DbSchema

  @statuses ["active", "pending", "paused", "halted", "cancelled", "completed", "expired"]

  schema "tenant_subscriptions" do
    field :provider, :string
    field :provider_subscription_id, :string
    field :plan_code, :string
    field :status, :string, default: "pending"
    field :quantity, :integer, default: 1
    field :current_start_at, :utc_datetime_usec
    field :current_end_at, :utc_datetime_usec
    field :next_charge_at, :utc_datetime_usec
    field :cancelled_at, :utc_datetime_usec
    field :grace_expires_at, :utc_datetime_usec
    field :payment_method, :string
    field :has_scheduled_changes, :boolean, default: false
    field :change_scheduled_at, :utc_datetime_usec
    field :pending_plan_code, :string
    field :short_url, :string
    field :metadata, :map, default: %{}

    belongs_to :tenant, Swati.Tenancy.Tenant

    timestamps()
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [
      :tenant_id,
      :provider,
      :provider_subscription_id,
      :plan_code,
      :status,
      :quantity,
      :current_start_at,
      :current_end_at,
      :next_charge_at,
      :cancelled_at,
      :grace_expires_at,
      :payment_method,
      :has_scheduled_changes,
      :change_scheduled_at,
      :pending_plan_code,
      :short_url,
      :metadata
    ])
    |> validate_required([:tenant_id, :provider, :provider_subscription_id, :plan_code, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:provider, :provider_subscription_id])
  end
end
