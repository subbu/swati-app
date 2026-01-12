defmodule Swati.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :string, null: false
      add :tool_name, :string, null: false
      add :description, :string
      add :endpoint_url, :string, null: false
      add :http_method, :string, null: false, default: "post"
      add :timeout_secs, :integer, null: false, default: 15
      add :status, :string, null: false, default: "active"
      add :headers, :map, null: false, default: %{}
      add :input_schema, :map, null: false, default: %{}
      add :sample_payload, :map
      add :auth_type, :string, null: false, default: "none"
      add :auth_secret_id, references(:secrets, type: :binary_id, on_delete: :nilify_all)
      add :last_tested_at, :utc_datetime_usec
      add :last_test_status, :string
      add :last_test_error, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:webhooks, [:tenant_id])
    create unique_index(:webhooks, [:tenant_id, :name])
    create unique_index(:webhooks, [:tenant_id, :tool_name])

    create table(:agent_webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :agent_id, references(:agents, type: :binary_id, on_delete: :delete_all), null: false

      add :webhook_id, references(:webhooks, type: :binary_id, on_delete: :delete_all),
        null: false

      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:agent_webhooks, [:agent_id, :webhook_id])
  end
end
