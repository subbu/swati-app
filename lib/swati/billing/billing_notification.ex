defmodule Swati.Billing.BillingNotification do
  use Swati.DbSchema

  @statuses ["pending", "sent", "failed", "skipped"]

  schema "billing_notifications" do
    field :kind, :string
    field :status, :string, default: "pending"
    field :scheduled_at, :utc_datetime_usec
    field :sent_at, :utc_datetime_usec
    field :error, :string
    field :metadata, :map, default: %{}

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :tenant_subscription, Swati.Billing.TenantSubscription

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :tenant_id,
      :tenant_subscription_id,
      :kind,
      :status,
      :scheduled_at,
      :sent_at,
      :error,
      :metadata
    ])
    |> validate_required([:tenant_id, :tenant_subscription_id, :kind, :status])
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:tenant_subscription_id, :kind])
  end
end
