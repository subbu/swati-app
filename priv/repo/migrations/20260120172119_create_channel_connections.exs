defmodule Swati.Repo.Migrations.CreateChannelConnections do
  use Ecto.Migration

  def change do
    create table(:channel_connections, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :channel_id, references(:channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :endpoint_id, references(:endpoints, type: :binary_id, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :status, :string, null: false, default: "active"
      add :auth_secret_id, references(:secrets, type: :binary_id, on_delete: :nilify_all)
      add :last_synced_at, :utc_datetime_usec
      add :metadata, :map

      timestamps(type: :utc_datetime_usec)
    end

    create index(:channel_connections, [:tenant_id])
    create index(:channel_connections, [:channel_id])
    create index(:channel_connections, [:provider])
    create unique_index(:channel_connections, [:endpoint_id])
  end
end
