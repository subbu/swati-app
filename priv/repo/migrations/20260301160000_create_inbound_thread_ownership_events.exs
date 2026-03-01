defmodule Swati.Repo.Migrations.CreateInboundThreadOwnershipEvents do
  use Ecto.Migration

  def change do
    create table(:inbound_thread_ownership_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      add :session_id, references(:sessions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :delivery_id,
          references(:inbound_deliveries, type: :binary_id, on_delete: :nilify_all)

      add :thread_key, :string, null: false

      add :previous_agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all)

      add :owner_agent_id, references(:agents, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :reason, :string, null: false
      add :source, :string, null: false, default: "inbound"
      add :metadata, :map
      add :resolved_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:inbound_thread_ownership_events, [:tenant_id])
    create index(:inbound_thread_ownership_events, [:session_id])
    create index(:inbound_thread_ownership_events, [:thread_key])
    create index(:inbound_thread_ownership_events, [:owner_agent_id])
    create index(:inbound_thread_ownership_events, [:resolved_at])
  end
end
