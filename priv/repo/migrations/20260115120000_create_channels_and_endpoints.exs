defmodule Swati.Repo.Migrations.CreateChannelsAndEndpoints do
  use Ecto.Migration

  def change do
    create table(:channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :key, :string, null: false
      add :type, :string, null: false
      add :status, :string, null: false, default: "active"
      add :capabilities, :map
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:channels, [:tenant_id])
    create unique_index(:channels, [:tenant_id, :key])

    create table(:channel_integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :integration_id, references(:integrations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channel_integrations, [:channel_id, :integration_id])

    create table(:channel_webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all),
        null: false

      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:channel_webhooks, [:channel_id, :webhook_id])

    create table(:endpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :address, :string, null: false
      add :display_name, :string
      add :status, :string, null: false, default: "active"
      add :routing_policy, :map
      add :metadata, :map

      add :phone_number_id, references(:phone_numbers, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:endpoints, [:tenant_id])
    create index(:endpoints, [:channel_id])
    create unique_index(:endpoints, [:tenant_id, :channel_id, :address])
    create unique_index(:endpoints, [:phone_number_id])
  end
end
