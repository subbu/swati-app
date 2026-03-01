defmodule Swati.Inbound.Delivery do
  use Swati.DbSchema

  @statuses [:received, :processing, :processed, :failed, :duplicate, :ignored]

  schema "inbound_deliveries" do
    field :provider, :string
    field :provider_event_id, :string
    field :idempotency_key, :string
    field :event_type, :string
    field :status, Ecto.Enum, values: @statuses, default: :received
    field :signature_valid, :boolean
    field :signature_error, :string
    field :request_headers, :map
    field :payload, :map
    field :normalized_payload, :map
    field :route_details, :map
    field :runtime_result, :map
    field :processing_error, :string
    field :received_at, :utc_datetime_usec
    field :processed_at, :utc_datetime_usec

    belongs_to :tenant, Swati.Tenancy.Tenant
    belongs_to :connector, Swati.Inbound.Connector

    timestamps()
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [
      :tenant_id,
      :connector_id,
      :provider,
      :provider_event_id,
      :idempotency_key,
      :event_type,
      :status,
      :signature_valid,
      :signature_error,
      :request_headers,
      :payload,
      :normalized_payload,
      :route_details,
      :runtime_result,
      :processing_error,
      :received_at,
      :processed_at
    ])
    |> validate_required([
      :tenant_id,
      :connector_id,
      :provider,
      :idempotency_key,
      :status,
      :received_at
    ])
    |> unique_constraint(:idempotency_key,
      name: :inbound_deliveries_connector_id_idempotency_key_index
    )
    |> unique_constraint(:provider_event_id,
      name: :inbound_deliveries_connector_id_provider_event_id_index
    )
  end
end
