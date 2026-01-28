defmodule Swati.Repo.Migrations.CreateBillingCore do
  use Ecto.Migration

  def change do
    create table(:billing_plans) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :amount, :integer, null: false
      add :currency, :string, null: false
      add :entitlements, :map, null: false, default: %{}
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create unique_index(:billing_plans, [:code])

    create table(:billing_plan_providers) do
      add :plan_id, references(:billing_plans, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_plan_id, :string, null: false

      timestamps()
    end

    create unique_index(:billing_plan_providers, [:provider, :provider_plan_id])
    create unique_index(:billing_plan_providers, [:plan_id, :provider])

    create table(:billing_customers) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_customer_id, :string
      add :email, :string
      add :contact, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:billing_customers, [:tenant_id, :provider])

    create unique_index(:billing_customers, [:provider, :provider_customer_id],
             where: "provider_customer_id IS NOT NULL"
           )

    create table(:provider_subscriptions) do
      add :provider, :string, null: false
      add :provider_subscription_id, :string, null: false
      add :provider_customer_id, :string
      add :provider_plan_id, :string
      add :provider_status, :string
      add :quantity, :integer, null: false, default: 1
      add :current_start_at, :utc_datetime_usec
      add :current_end_at, :utc_datetime_usec
      add :next_charge_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:provider_subscriptions, [:provider, :provider_subscription_id])
    create index(:provider_subscriptions, [:provider_customer_id])

    create table(:tenant_subscriptions) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_subscription_id, :string, null: false
      add :plan_code, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :quantity, :integer, null: false, default: 1
      add :current_start_at, :utc_datetime_usec
      add :current_end_at, :utc_datetime_usec
      add :next_charge_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
      add :grace_expires_at, :utc_datetime_usec
      add :payment_method, :string
      add :has_scheduled_changes, :boolean, null: false, default: false
      add :change_scheduled_at, :utc_datetime_usec
      add :pending_plan_code, :string
      add :short_url, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:tenant_subscriptions, [:tenant_id])
    create unique_index(:tenant_subscriptions, [:provider, :provider_subscription_id])

    create table(:billing_events) do
      add :provider, :string, null: false
      add :provider_event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :received_at, :utc_datetime_usec, null: false
      add :processed_at, :utc_datetime_usec
      add :processing_error, :string

      timestamps()
    end

    create unique_index(:billing_events, [:provider, :provider_event_id])

    create table(:billing_cycles) do
      add :tenant_subscription_id, references(:tenant_subscriptions, on_delete: :delete_all),
        null: false

      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :start_at, :utc_datetime_usec, null: false
      add :end_at, :utc_datetime_usec, null: false
      add :status, :string, null: false, default: "open"
      add :usage_summary, :map, default: %{}

      timestamps()
    end

    create index(:billing_cycles, [:tenant_id])
    create index(:billing_cycles, [:tenant_subscription_id])
    create unique_index(:billing_cycles, [:tenant_subscription_id, :start_at, :end_at])

    create table(:billing_usage_counters) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :cycle_id, references(:billing_cycles, on_delete: :delete_all), null: false
      add :metric, :string, null: false
      add :amount, :integer, null: false, default: 0

      timestamps(updated_at: false)
    end

    create unique_index(:billing_usage_counters, [:cycle_id, :metric])
    create index(:billing_usage_counters, [:tenant_id])

    create table(:billing_usage_events) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false
      add :cycle_id, references(:billing_cycles, on_delete: :delete_all), null: false
      add :metric, :string, null: false
      add :amount, :integer, null: false
      add :source_type, :string
      add :source_id, :binary_id
      add :occurred_at, :utc_datetime_usec

      timestamps(updated_at: false)
    end

    create index(:billing_usage_events, [:tenant_id])
    create index(:billing_usage_events, [:cycle_id])

    create table(:billing_notifications) do
      add :tenant_id, references(:tenants, on_delete: :delete_all), null: false

      add :tenant_subscription_id,
          references(:tenant_subscriptions, on_delete: :delete_all),
          null: false

      add :kind, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :scheduled_at, :utc_datetime_usec
      add :sent_at, :utc_datetime_usec
      add :error, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:billing_notifications, [:tenant_id])
    create unique_index(:billing_notifications, [:tenant_subscription_id, :kind])
  end
end
