defmodule Swati.Repo.Migrations.CreateCases do
  use Ecto.Migration

  def change do
    create table(:cases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :nilify_all)
      add :assigned_agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)
      add :assigned_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false, default: "new"
      add :priority, :string, null: false, default: "normal"
      add :category, :string
      add :title, :string
      add :summary, :text
      add :memory, :map
      add :opened_at, :utc_datetime_usec
      add :resolved_at, :utc_datetime_usec
      add :closed_at, :utc_datetime_usec
      add :sla_due_at, :utc_datetime_usec
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:cases, [:tenant_id])
    create index(:cases, [:tenant_id, :status])
    create index(:cases, [:customer_id])
    create index(:cases, [:assigned_agent_id])
    create index(:cases, [:assigned_user_id])
  end
end
