defmodule Swati.Billing.Management do
  alias Swati.Billing.{
    BillingCustomer,
    BillingEvent,
    ProviderSubscription,
    TenantSubscription
  }

  alias Swati.Repo

  def upsert_billing_customer(attrs) when is_map(attrs) do
    replace_fields = attrs |> Map.keys() |> Enum.uniq() |> Kernel.++([:updated_at])

    %BillingCustomer{}
    |> BillingCustomer.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, replace_fields},
      conflict_target: [:tenant_id, :provider],
      returning: true
    )
  end

  def upsert_provider_subscription(attrs) when is_map(attrs) do
    replace_fields = attrs |> Map.keys() |> Enum.uniq() |> Kernel.++([:updated_at])

    %ProviderSubscription{}
    |> ProviderSubscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, replace_fields},
      conflict_target: [:provider, :provider_subscription_id],
      returning: true
    )
  end

  def upsert_tenant_subscription(attrs) when is_map(attrs) do
    replace_fields = attrs |> Map.keys() |> Enum.uniq() |> Kernel.++([:updated_at])

    %TenantSubscription{}
    |> TenantSubscription.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, replace_fields},
      conflict_target: [:provider, :provider_subscription_id],
      returning: true
    )
  end

  def mark_event_processed(%BillingEvent{} = event) do
    event
    |> BillingEvent.changeset(%{
      processed_at: DateTime.utc_now(),
      processing_error: nil
    })
    |> Repo.update()
  end

  def mark_event_failed(%BillingEvent{} = event, error) do
    event
    |> BillingEvent.changeset(%{
      processed_at: DateTime.utc_now(),
      processing_error: to_string(error)
    })
    |> Repo.update()
  end
end
