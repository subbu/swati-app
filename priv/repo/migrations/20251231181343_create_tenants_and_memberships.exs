defmodule Swati.Repo.Migrations.CreateTenantsAndMemberships do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :timezone, :string, null: false, default: "Asia/Kolkata"
      add :plan, :string, null: false, default: "starter"
      add :status, :string, null: false, default: "active"

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:tenants, [:slug])

    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memberships, [:tenant_id, :user_id])
    create unique_index(:memberships, [:user_id])
  end
end
