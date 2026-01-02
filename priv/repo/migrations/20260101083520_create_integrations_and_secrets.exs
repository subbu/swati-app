defmodule Swati.Repo.Migrations.CreateIntegrationsAndSecrets do
  use Ecto.Migration

  def change do
    create table(:secrets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :value, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:secrets, [:tenant_id])
    create unique_index(:secrets, [:tenant_id, :name])

    create table(:integrations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :name, :string, null: false
      add :endpoint_url, :string, null: false
      add :origin, :string, null: false, default: "https://customer.example.com"
      add :protocol_version, :string, null: false, default: "2025-06-18"
      add :timeout_secs, :integer, null: false, default: 15
      add :status, :string, null: false, default: "active"
      add :allowed_tools, :map, null: false
      add :tool_prefix, :string
      add :auth_type, :string, null: false, default: "none"
      add :auth_secret_id, references(:secrets, type: :binary_id, on_delete: :nilify_all)
      add :last_tested_at, :utc_datetime_usec
      add :last_test_status, :string
      add :last_test_error, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:integrations, [:tenant_id])
    create unique_index(:integrations, [:tenant_id, :name])
  end
end
