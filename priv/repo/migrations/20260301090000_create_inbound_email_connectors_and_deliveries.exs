defmodule Swati.Repo.Migrations.CreateInboundEmailConnectorsAndDeliveries do
  use Ecto.Migration

  def change do
    create table(:inbound_connectors, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :provider, :string, null: false
      add :status, :string, null: false, default: "active"
      add :endpoint_token, :string, null: false
      add :signing_secret_id, references(:secrets, type: :binary_id, on_delete: :nilify_all)
      add :default_channel_key, :string, null: false, default: "email"
      add :default_endpoint_address, :string
      add :default_agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
      add :routing_mode, :string, null: false, default: "continuity_first"
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:inbound_connectors, [:tenant_id])
    create index(:inbound_connectors, [:provider])
    create unique_index(:inbound_connectors, [:endpoint_token])
    create unique_index(:inbound_connectors, [:tenant_id, :name])

    create table(:inbound_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :connector_id,
          references(:inbound_connectors, type: :binary_id, on_delete: :delete_all),
          null: false

      add :provider, :string, null: false
      add :provider_event_id, :string
      add :idempotency_key, :string, null: false
      add :event_type, :string
      add :status, :string, null: false, default: "received"
      add :signature_valid, :boolean
      add :signature_error, :string
      add :request_headers, :map
      add :payload, :map
      add :normalized_payload, :map
      add :route_details, :map
      add :runtime_result, :map
      add :processing_error, :string
      add :received_at, :utc_datetime_usec, null: false
      add :processed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:inbound_deliveries, [:tenant_id])
    create index(:inbound_deliveries, [:connector_id])
    create index(:inbound_deliveries, [:status])
    create index(:inbound_deliveries, [:received_at])
    create unique_index(:inbound_deliveries, [:connector_id, :idempotency_key])
    create unique_index(:inbound_deliveries, [:connector_id, :provider_event_id])

    create table(:agent_inbound_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :priority, :integer, null: false, default: 100
      add :action, :string, null: false, default: "owner"
      add :predicates, :map, null: false, default: %{}
      add :defaults, :map
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:agent_inbound_rules, [:tenant_id])
    create index(:agent_inbound_rules, [:agent_id])
    create index(:agent_inbound_rules, [:enabled])
    create index(:agent_inbound_rules, [:priority])
    create unique_index(:agent_inbound_rules, [:tenant_id, :agent_id, :name])
  end
end
