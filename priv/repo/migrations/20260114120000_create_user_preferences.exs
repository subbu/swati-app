defmodule Swati.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :map, null: false, default: %{}
      add :schema_version, :integer, null: false, default: 1

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_preferences, [:tenant_id])
    create index(:user_preferences, [:user_id])
    create unique_index(:user_preferences, [:tenant_id, :user_id, :key])
  end
end
