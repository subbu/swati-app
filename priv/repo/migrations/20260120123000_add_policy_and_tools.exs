defmodule Swati.Repo.Migrations.AddPolicyAndTools do
  use Ecto.Migration

  def change do
    alter table(:tenants) do
      add :policy, :map, null: false, default: %{}
    end

    alter table(:channels) do
      add :policy, :map, null: false, default: %{}
    end

    alter table(:cases) do
      add :policy, :map, null: false, default: %{}
    end

    alter table(:session_events) do
      add :category, :string, null: false, default: "system"
    end

    create index(:session_events, [:session_id, :category])

    create table(:tools, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :string
      add :origin, :string, null: false, default: "manual"
      add :status, :string, null: false, default: "active"
      add :risk, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tools, [:tenant_id, :name])
    create index(:tools, [:tenant_id, :origin])
    create index(:tools, [:tenant_id, :status])
  end
end
