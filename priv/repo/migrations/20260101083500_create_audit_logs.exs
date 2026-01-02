defmodule Swati.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :binary_id, null: false
      add :changes, :map
      add :ip, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime_usec)
    end

    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:tenant_id, :inserted_at])
    create index(:audit_logs, [:tenant_id, :entity_type, :entity_id])
  end
end
