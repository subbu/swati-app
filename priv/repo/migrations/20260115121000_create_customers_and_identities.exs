defmodule Swati.Repo.Migrations.CreateCustomersAndIdentities do
  use Ecto.Migration

  def change do
    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string
      add :status, :string, null: false, default: "active"
      add :primary_email, :string
      add :primary_phone, :string
      add :timezone, :string
      add :language, :string
      add :preferences, :map
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:customers, [:tenant_id])
    create index(:customers, [:tenant_id, :status])

    create table(:customer_identities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :kind, :string, null: false
      add :external_id, :string
      add :address, :string
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:customer_identities, [:tenant_id])
    create index(:customer_identities, [:customer_id])
    create index(:customer_identities, [:channel_id])
    create index(:customer_identities, [:tenant_id, :channel_id, :address])
    create unique_index(:customer_identities, [:tenant_id, :channel_id, :external_id])
  end
end
