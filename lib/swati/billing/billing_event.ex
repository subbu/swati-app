defmodule Swati.Billing.BillingEvent do
  use Swati.DbSchema

  schema "billing_events" do
    field :provider, :string
    field :provider_event_id, :string
    field :event_type, :string
    field :payload, :map
    field :received_at, :utc_datetime_usec
    field :processed_at, :utc_datetime_usec
    field :processing_error, :string

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :provider,
      :provider_event_id,
      :event_type,
      :payload,
      :received_at,
      :processed_at,
      :processing_error
    ])
    |> validate_required([:provider, :provider_event_id, :event_type, :payload, :received_at])
    |> unique_constraint([:provider, :provider_event_id])
  end
end
